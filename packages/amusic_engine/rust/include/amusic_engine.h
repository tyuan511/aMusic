#ifndef AMUSIC_ENGINE_H
#define AMUSIC_ENGINE_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct AmusicPlayer AmusicPlayer;

/* One peaking filter (12 bytes). */
typedef struct {
  float freq;
  float q;
  float gain_db;
} AmusicBand;

/* Polled by the UI. state: 0 idle, 1 loading, 2 ready, 3 ended, 4 error. */
typedef struct {
  uint32_t state;
  bool playing;
  double position;
  double duration; /* < 0 when unknown */
  uint64_t advance_seq; /* bumps on every gapless advance to the queued track */
  uint64_t load_seq;    /* bumps when a load finished (ok or error) */
} AmusicStatus;

const char *amusic_last_error(void);

AmusicPlayer *amusic_player_new(void);
void amusic_player_free(AmusicPlayer *p);

/* Asynchronous: returns 0 when accepted; watch status.state / load_seq. */
int32_t amusic_player_load(AmusicPlayer *p, const char *url, double start_secs);
/* Queue the following track for a gapless start; NULL clears. */
void amusic_player_set_next(AmusicPlayer *p, const char *url);
void amusic_player_play(AmusicPlayer *p);
void amusic_player_pause(AmusicPlayer *p);
void amusic_player_stop(AmusicPlayer *p);
void amusic_player_seek(AmusicPlayer *p, double secs);
void amusic_player_set_volume(AmusicPlayer *p, float volume);
void amusic_player_set_speed(AmusicPlayer *p, double speed);
/* effect: 0 none, 1 3D surround, 2 360 rotation, 3 LiveHouse, 4 exciter. */
void amusic_player_set_eq(AmusicPlayer *p, const AmusicBand *bands, size_t count,
                          float gain_db, bool limiter, uint32_t effect);

void amusic_player_status(AmusicPlayer *p, AmusicStatus *out);
/* Copies and clears the last error; returns its length. */
size_t amusic_player_take_error(AmusicPlayer *p, char *buf, size_t cap);
uint32_t amusic_player_sample_rate(AmusicPlayer *p);

#ifdef __cplusplus
}
#endif

#endif
