/*#############################################################################
FILE NAME   : shm_tool.h
DESCRIPTION : 운영 도구 공용 — 이름 검사·레이아웃 결정·attach·헤더 출력·attach 프로세스 수
#############################################################################*/
#ifndef SHM_TOOL_H
#define SHM_TOOL_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>

#include "shm_segment.h"

/* 도구 종료 코드 — shmctl.sh·런북이 이 값으로 분기한다 */
#define TOOL_EXIT_OK        0   /* 정상·성공 */
#define TOOL_EXIT_ERROR     1   /* 사용법 오류·실행 실패 */
#define TOOL_EXIT_CORRUPT   2   /* 손상 판정(점검·dry-run) */
#define TOOL_EXIT_REFUSED   3   /* 안전 조건 미충족으로 거부 */

#define TOOL_USER_MAX       64u

/* POSIX 이름 검사: "/" + [A-Za-z0-9._-] 1~30자(macOS 31자 한도) */
bool ShmToolNameValid(const char *name);

/*=============================================================================
FUNCTION    : ShmToolLayout
DESCRIPTION : 품목 레이아웃을 정한다. rec_cap 은 cap_override(0 이 아니면) 또는
              헤더 사본의 값을 쓴다. 헤더의 값이 비정상이면 실패한다
PARAMETERS  : const ShmHdr *peek    - ShmSegPeekHdr 결과
              uint32_t cap_override - --cap 값(0 이면 헤더 값)
              ShmLayout *out        - 결과
RETURNED    : 0 성공, -EINVAL rec_cap 을 정할 수 없음
=============================================================================*/
int ShmToolLayout(const ShmHdr *peek, uint32_t cap_override, ShmLayout *out);

/*=============================================================================
FUNCTION    : ShmToolAttachCount
DESCRIPTION : 세그먼트를 매핑한 다른 프로세스 수를 센다(리눅스: /proc/<pid>/maps).
              자기 프로세스는 제외한다
PARAMETERS  : const char *name - POSIX 이름
RETURNED    : 0 이상 프로세스 수, -ENOTSUP 이 플랫폼에서 셀 수 없음(macOS)
=============================================================================*/
int ShmToolAttachCount(const char *name);

const char *ShmToolStateName(uint32_t state);

/* 헤더 요약을 key=value 한 줄씩 출력한다. 레코드 내용은 출력하지 않는다 */
void ShmToolPrintHdr(FILE *out, const char *name, const ShmHdr *hdr);

/* 실행 사용자 이름(getpwuid, 실패하면 uid 숫자) */
void ShmToolUserName(char *out, size_t out_size);

/* 지역 시각 ISO-8601(초, 오프셋 포함) */
void ShmToolNowText(char *out, size_t out_size);

#endif /* SHM_TOOL_H */
