################################################################################
# FILE NAME   : Makefile
# DESCRIPTION : 공유메모리 운영 도구(shm_view·shm_recover·shm_admin) 빌드와 도구 테스트
################################################################################
# 사용법:
#   make                 도구 빌드(src/shm·src/log 코드를 그대로 링크한다)
#   make test            도구 빌드 후 시나리오 테스트(SHM_TOOLS_BATS, 기본은 Arachne tests/shm_tools.bats)
#   make OUT=<디렉터리>   산출물을 다른 디렉터리에 만든다(테스트가 임시 디렉터리로 쓴다)
#   make clean
# 리눅스와 macOS(clang) 모두에서 -std=c11 -Wall -Wextra -Werror 로 빌드된다.

CC       ?= cc
CSTD     := -std=c11
WARN     := -Wall -Wextra -Werror
CFLAGS   ?= -O1 -g
OUT      ?= .
UNAME_S  := $(shell uname -s)

SHM_DIR  := ../src/shm
LOG_DIR  := ../src/log
INC      := -I. -I$(SHM_DIR) -I$(LOG_DIR)

LDLIBS   := -pthread
ifeq ($(UNAME_S),Linux)
LDLIBS   += -lrt
endif

SHM_SRCS := $(SHM_DIR)/shm_segment.c $(SHM_DIR)/sorted_table.c
LOG_SRCS := $(LOG_DIR)/log.c
TOOL_LIB := shm_tool.c
HDRS     := shm_tool.h item_field.h rec_loader.h $(SHM_DIR)/shm_segment.h \
            $(SHM_DIR)/sorted_table.h $(LOG_DIR)/log.h

BINS     := $(OUT)/shm_view $(OUT)/shm_recover $(OUT)/shm_admin $(OUT)/test_shm_fixture
BUILD    = $(CC) $(CSTD) $(WARN) $(CFLAGS) $(INC) -o $@ $(filter %.c,$^) $(LDLIBS)
# 시나리오 테스트 위치 — 프로젝트로 복사했으면 SHM_TOOLS_BATS=<경로> 로 바꾼다
SHM_TOOLS_BATS ?= ../../../../tests/shm_tools.bats

.PHONY: all test clean

all: $(BINS)

$(OUT)/shm_view: shm_view.c item_field.c $(TOOL_LIB) $(SHM_SRCS) $(LOG_SRCS) $(HDRS) | $(OUT)
	$(BUILD)

$(OUT)/shm_recover: shm_recover.c rec_loader_file.c rec_loader_db.c $(TOOL_LIB) $(SHM_SRCS) $(LOG_SRCS) $(HDRS) | $(OUT)
	$(BUILD)

$(OUT)/shm_admin: shm_admin.c $(TOOL_LIB) $(SHM_SRCS) $(HDRS) | $(OUT)
	$(BUILD)

$(OUT)/test_shm_fixture: test_shm_fixture.c $(TOOL_LIB) $(SHM_SRCS) $(HDRS) | $(OUT)
	$(BUILD)

$(OUT):
	mkdir -p $@

test: all
	SHM_TOOLS_BIN_DIR="$(abspath $(OUT))" bats "$(SHM_TOOLS_BATS)"

clean:
	rm -rf $(BINS) *.dSYM shmctl.log shm_view_audit.log
