/* VAMP (Virtual Audio Manipulation Program) plugin code --old */
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#define SAMPLE_RATE 44100
#define MAX_DELAY 0.5 /* seconds */

typedef struct {
    float *buffer;
    int size;
    int write_pos;
    float feedback;
    float delay_time;
} DelayLine;

void init_delay(DelayLine *dl, float delay_time, float feedback) {
    dl->size = (int)(delay_time * SAMPLE_RATE);
    dl->buffer = (float *)calloc(dl->size, sizeof(float));
    dl->write_pos = 0;
    dl->feedback = feedback;
    dl->delay_time = delay_time;
}

float process_delay(DelayLine *dl, float input) {
    int read_pos = (dl->write_pos - dl->size + dl->size) % dl->size;
    float output = dl->buffer[read_pos];
    dl->buffer[dl->write_pos] = input + output * dl->feedback;
    dl->write_pos = (dl->write_pos + 1) % dl->size;
    return output;
}

void free_delay(DelayLine *dl) {
    free(dl->buffer);
}

int main() {
    DelayLine dl;
    init_delay(&dl, 0.3, 0.5); /* 300ms delay, 50% feedback */
    float input = 1.0; /* Test input sample */
    for (int i = 0; i < 10; i++) {
        float output = process_delay(&dl, input);
        printf("Sample %d: %f\n", i, output);
        input = 0.0; /* One-shot impulse */
    }
    free_delay(&dl);
    return 0;
}
