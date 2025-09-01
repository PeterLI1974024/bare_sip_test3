#include <stdint.h>

#if defined(__ANDROID__)
  #define EXPORT __attribute__((visibility("default")))
#else
  #define EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

// 測試用假函式
EXPORT const char* bs_version(void) {
    return "dummy wrapper v1.0";
}

EXPORT int bs_init(void) {
    return 0; // 假裝初始化成功
}

EXPORT void bs_close(void) {
    // no-op
}
