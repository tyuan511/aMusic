/// Semantic version as used by release tags (`v2.1.0`, `2.1.0-beta.2`,
/// pubspec `2.0.0+20`).
///
/// A missing minor / patch is 0 (`v2.1` == `2.1.0`), build metadata is
/// ignored, and precedence follows SemVer 2.0: `2.0.0-beta.2 < 2.0.0-rc.1 <
/// 2.0.0`, numeric pre-release identifiers sort numerically and below
/// alphanumeric ones.
class ReleaseVersion implements Comparable<ReleaseVersion> {
  const ReleaseVersion(
    this.major,
    this.minor,
    this.patch, [
    this.preRelease = const [],
  ]);

  final int major;
  final int minor;
  final int patch;
  final List<String> preRelease;

  static final RegExp _pattern = RegExp(
    r'^[vV]?(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$',
  );

  /// `null` when [raw] is not a version (branch name, garbage).
  static ReleaseVersion? parse(String raw) {
    final match = _pattern.firstMatch(raw.trim());
    if (match == null) return null;
    final pre = match.group(4);
    final identifiers = pre == null ? const <String>[] : pre.split('.');
    if (identifiers.any((id) => id.isEmpty)) return null;
    return ReleaseVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2) ?? '0'),
      int.parse(match.group(3) ?? '0'),
      List.unmodifiable(identifiers),
    );
  }

  bool get isPreRelease => preRelease.isNotEmpty;

  @override
  int compareTo(ReleaseVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    if (!isPreRelease && !other.isPreRelease) return 0;
    // A final release outranks its pre-releases.
    if (!isPreRelease) return 1;
    if (!other.isPreRelease) return -1;
    final count = preRelease.length < other.preRelease.length
        ? preRelease.length
        : other.preRelease.length;
    for (var i = 0; i < count; i++) {
      final a = preRelease[i];
      final b = other.preRelease[i];
      final na = int.tryParse(a);
      final nb = int.tryParse(b);
      final int order;
      if (na != null && nb != null) {
        order = na.compareTo(nb);
      } else if (na != null) {
        order = -1;
      } else if (nb != null) {
        order = 1;
      } else {
        order = a.compareTo(b);
      }
      if (order != 0) return order;
    }
    return preRelease.length.compareTo(other.preRelease.length);
  }

  bool operator >(ReleaseVersion other) => compareTo(other) > 0;
  bool operator <(ReleaseVersion other) => compareTo(other) < 0;

  @override
  bool operator ==(Object other) =>
      other is ReleaseVersion && compareTo(other) == 0;

  @override
  int get hashCode =>
      Object.hash(major, minor, patch, Object.hashAll(preRelease));

  @override
  String toString() =>
      '$major.$minor.$patch${isPreRelease ? '-${preRelease.join('.')}' : ''}';
}

/// Whether [candidate] is newer than [current]; `false` when either does not
/// parse.
bool isNewerVersion(String candidate, String current) {
  final a = ReleaseVersion.parse(candidate);
  final b = ReleaseVersion.parse(current);
  return a != null && b != null && a > b;
}
