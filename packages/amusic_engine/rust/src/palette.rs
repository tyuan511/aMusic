//! Cover colours: a Material-style palette (dominant, vibrant, muted, light and
//! dark variants) from a small median-cut quantisation of the picture.

use image::imageops::FilterType;

/// The picture is shrunk to this edge before quantising.
const SAMPLE_EDGE: u32 = 112;
const MAX_COLORS: usize = 16;

#[derive(Clone, Copy, Debug)]
pub struct Swatch {
    pub rgb: [u8; 3],
    pub population: u32,
    hsl: [f32; 3],
}

#[derive(Debug, Default)]
pub struct Palette {
    /// All swatches, most populous first.
    pub swatches: Vec<Swatch>,
    pub dominant: Option<Swatch>,
    pub vibrant: Option<Swatch>,
    pub light_vibrant: Option<Swatch>,
    pub dark_vibrant: Option<Swatch>,
    pub muted: Option<Swatch>,
    pub light_muted: Option<Swatch>,
    pub dark_muted: Option<Swatch>,
}

fn to_hsl(rgb: [u8; 3]) -> [f32; 3] {
    let [r, g, b] = rgb.map(|c| f32::from(c) / 255.0);
    let max = r.max(g).max(b);
    let min = r.min(g).min(b);
    let delta = max - min;
    let l = (max + min) / 2.0;
    if delta == 0.0 {
        return [0.0, 0.0, l];
    }
    let s = delta / (1.0 - (2.0 * l - 1.0).abs());
    let h = if max == r {
        ((g - b) / delta).rem_euclid(6.0)
    } else if max == g {
        (b - r) / delta + 2.0
    } else {
        (r - g) / delta + 4.0
    };
    [h * 60.0, s, l]
}

/// Near white, near black and the skin-tone "red I line" never make a palette.
fn allowed(hsl: [f32; 3]) -> bool {
    let [h, s, l] = hsl;
    !(l >= 0.95 || l <= 0.05 || ((10.0..=37.0).contains(&h) && s <= 0.82))
}

struct Target {
    light: [f32; 3],
    sat: [f32; 3],
}

const LIGHT_VIBRANT: Target = Target {
    light: [0.55, 0.74, 1.0],
    sat: [0.35, 1.0, 1.0],
};
const VIBRANT: Target = Target {
    light: [0.3, 0.5, 0.7],
    sat: [0.35, 1.0, 1.0],
};
const DARK_VIBRANT: Target = Target {
    light: [0.0, 0.26, 0.45],
    sat: [0.35, 1.0, 1.0],
};
const LIGHT_MUTED: Target = Target {
    light: [0.55, 0.74, 1.0],
    sat: [0.0, 0.3, 0.4],
};
const MUTED: Target = Target {
    light: [0.3, 0.5, 0.7],
    sat: [0.0, 0.3, 0.4],
};
const DARK_MUTED: Target = Target {
    light: [0.0, 0.26, 0.45],
    sat: [0.0, 0.3, 0.4],
};

fn pick(swatches: &[Swatch], taken: &mut Vec<[u8; 3]>, max_pop: f32, t: &Target) -> Option<Swatch> {
    let mut best: Option<(f32, Swatch)> = None;
    for s in swatches {
        let [_, sat, light] = s.hsl;
        if sat < t.sat[0]
            || sat > t.sat[2]
            || light < t.light[0]
            || light > t.light[2]
            || taken.contains(&s.rgb)
        {
            continue;
        }
        let score = 0.24 * (1.0 - (sat - t.sat[1]).abs())
            + 0.52 * (1.0 - (light - t.light[1]).abs())
            + 0.24 * (s.population as f32 / max_pop);
        if best.as_ref().is_none_or(|(b, _)| score > *b) {
            best = Some((score, *s));
        }
    }
    let swatch = best?.1;
    taken.push(swatch.rgb);
    Some(swatch)
}

/// Median cut over a 5-bit-per-channel histogram.
fn quantize(pixels: &[[u8; 3]]) -> Vec<Swatch> {
    let mut hist = std::collections::HashMap::<u16, u32>::new();
    for p in pixels {
        let key = u16::from(p[0] >> 3) << 10 | u16::from(p[1] >> 3) << 5 | u16::from(p[2] >> 3);
        *hist.entry(key).or_default() += 1;
    }
    let mut colors: Vec<(u16, u32)> = hist.into_iter().collect();
    colors.sort_unstable();
    let channel = |key: u16, c: usize| ((key >> (10 - 5 * c)) & 31) as u8;

    let mut boxes: Vec<Vec<(u16, u32)>> = vec![colors];
    while boxes.len() < MAX_COLORS {
        // Split the box with the largest population that still has two colours.
        let Some((idx, _)) = boxes
            .iter()
            .enumerate()
            .filter(|(_, b)| b.len() > 1)
            .max_by_key(|(_, b)| b.iter().map(|c| c.1).sum::<u32>())
        else {
            break;
        };
        let mut b = boxes.swap_remove(idx);
        let range = |c: usize| {
            let (lo, hi) = b.iter().fold((31u8, 0u8), |(lo, hi), &(k, _)| {
                (lo.min(channel(k, c)), hi.max(channel(k, c)))
            });
            hi - lo
        };
        let axis = (0..3).max_by_key(|&c| range(c)).unwrap_or(0);
        b.sort_unstable_by_key(|&(k, _)| channel(k, axis));
        let half = b.iter().map(|c| c.1).sum::<u32>() / 2;
        let mut acc = 0;
        let mut cut = b.len() - 1;
        for (i, c) in b.iter().enumerate() {
            acc += c.1;
            if acc >= half {
                cut = (i + 1).min(b.len() - 1);
                break;
            }
        }
        let tail = b.split_off(cut);
        boxes.push(b);
        boxes.push(tail);
    }

    let mut out: Vec<Swatch> = boxes
        .iter()
        .filter(|b| !b.is_empty())
        .map(|b| {
            let pop: u32 = b.iter().map(|c| c.1).sum();
            let avg = |c: usize| {
                let sum: u64 = b
                    .iter()
                    .map(|&(k, n)| u64::from(channel(k, c)) * u64::from(n))
                    .sum();
                // Back from 5 bits to 8, centred in the bucket.
                (((sum as f64 / f64::from(pop)) * 8.0) + 4.0)
                    .round()
                    .min(255.0) as u8
            };
            let rgb = [avg(0), avg(1), avg(2)];
            Swatch {
                rgb,
                population: pop,
                hsl: to_hsl(rgb),
            }
        })
        .collect();
    out.sort_by(|a, b| b.population.cmp(&a.population));
    out
}

pub fn extract(encoded: &[u8]) -> Option<Palette> {
    let img = image::load_from_memory(encoded).ok()?;
    let img = if img.width().max(img.height()) > SAMPLE_EDGE {
        img.resize(SAMPLE_EDGE, SAMPLE_EDGE, FilterType::Triangle)
    } else {
        img
    };
    let rgba = img.to_rgba8();
    let pixels: Vec<[u8; 3]> = rgba
        .pixels()
        .filter(|p| p[3] >= 128)
        .map(|p| [p[0], p[1], p[2]])
        .collect();
    if pixels.is_empty() {
        return None;
    }
    let swatches = quantize(&pixels);
    let usable: Vec<Swatch> = swatches
        .iter()
        .copied()
        .filter(|s| allowed(s.hsl))
        .collect();
    let max_pop = usable
        .iter()
        .map(|s| s.population)
        .max()
        .unwrap_or(1)
        .max(1) as f32;
    let mut taken = Vec::new();
    let vibrant = pick(&usable, &mut taken, max_pop, &VIBRANT);
    let light_vibrant = pick(&usable, &mut taken, max_pop, &LIGHT_VIBRANT);
    let dark_vibrant = pick(&usable, &mut taken, max_pop, &DARK_VIBRANT);
    let muted = pick(&usable, &mut taken, max_pop, &MUTED);
    let light_muted = pick(&usable, &mut taken, max_pop, &LIGHT_MUTED);
    let dark_muted = pick(&usable, &mut taken, max_pop, &DARK_MUTED);
    Some(Palette {
        dominant: usable
            .first()
            .copied()
            .or_else(|| swatches.first().copied()),
        swatches: usable,
        vibrant,
        light_vibrant,
        dark_vibrant,
        muted,
        light_muted,
        dark_muted,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn png(pixels: impl Fn(u32, u32) -> [u8; 3]) -> Vec<u8> {
        let img = image::RgbImage::from_fn(60, 60, |x, y| image::Rgb(pixels(x, y)));
        let mut out = std::io::Cursor::new(Vec::new());
        img.write_to(&mut out, image::ImageFormat::Png).unwrap();
        out.into_inner()
    }

    #[test]
    fn saturated_picture_has_a_vibrant_swatch_near_its_colour() {
        let p = extract(&png(|_, _| [30, 90, 220])).unwrap();
        let v = p.vibrant.expect("vibrant");
        assert!(v.rgb[2] > 180 && v.rgb[0] < 80, "{:?}", v.rgb);
        assert_eq!(p.dominant.unwrap().rgb, v.rgb);
    }

    #[test]
    fn two_tone_picture_yields_both_colours() {
        let p = extract(&png(
            |x, _| if x < 30 { [220, 40, 60] } else { [20, 60, 200] },
        ))
        .unwrap();
        assert!(p.swatches.len() >= 2);
    }

    #[test]
    fn white_or_garbage_gives_no_vibrant() {
        assert!(extract(&png(|_, _| [255, 255, 255]))
            .unwrap()
            .vibrant
            .is_none());
        assert!(extract(b"not an image").is_none());
    }
}
