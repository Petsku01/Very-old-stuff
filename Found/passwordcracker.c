/* Password cracker inspired by Elite in early 1990s */
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define MAX_PASSWD_LEN 8
#define SALT_LEN 2

/* Mock DES crypt function (simplified, not actual DES) */
char *mock_crypt(const char *pass, const char *salt) {
    static char result[14];
    snprintf(result, sizeof(result), "%s%s", salt, pass); /* Dummy hash */
    return result;
}

/* Brute-force guess for a single password */
int try_password(const char *target_hash, const char *salt) {
    char guess[MAX_PASSWD_LEN + 1];
    char *hashed;
    int i, j;

    /* Simple brute-force: try a-z for short passwords */
    for (i = 1; i <= 4; i++) { /* Limit to 4 chars for demo */
        for (j = 0; j < i; j++) guess[j] = 'a';
        guess[i] = '\0';

        while (guess[0] <= 'z') {
            hashed = mock_crypt(guess, salt);
            if (strcmp(hashed, target_hash) == 0) {
                printf("Password found: %s\n", guess);
                return 1;
            }
            /* Increment last character */
            guess[i-1]++;
            if (guess[i-1] > 'z') {
                guess[i-1] = 'a';
                if (i > 1) guess[i-2]++;
            }
        }
    }
    return 0;
}

int main() {
    const char *salt = "xy";
    const char *target_hash = "xyabcd"; /* Mock hash for demo */
    if (!try_password(target_hash, salt)) {
        printf("Password not found.\n");
    }
    return 0;
}
