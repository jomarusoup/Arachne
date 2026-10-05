################################################################################
# FILE NAME   : Makefile
# DESCRIPTION : 처리량 PoC 송신 시뮬레이터와 C 기준선 수신기 빌드
#                 make       — 최적화 빌드 (측정용 -O2)
#                 make asan  — ASan + UBSan 빌드 (정확성 점검용, 측정에 쓰지 않는다)
#                 make clean — 산출물 삭제
#               Linux gcc 와 macOS clang 에서 같은 명령으로 동작한다.
################################################################################

CC     ?= cc
BUILD  := build
STD    := -std=gnu11
WARN   := -Wall -Wextra -Werror
OPT    := -O2 -g
ASAN   := -O1 -g -fno-omit-frame-pointer -fsanitize=address,undefined -fno-sanitize-recover=undefined
HDRS   := common/poc_wire.h

.PHONY: all asan clean

all: $(BUILD)/poc_sender $(BUILD)/poc_receiver

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/poc_sender: sender/poc_sender.c $(HDRS) | $(BUILD)
	$(CC) $(STD) $(WARN) $(OPT) -o $@ sender/poc_sender.c

$(BUILD)/poc_receiver: receiver-c/poc_receiver.c $(HDRS) | $(BUILD)
	$(CC) $(STD) $(WARN) $(OPT) -o $@ receiver-c/poc_receiver.c

asan: | $(BUILD)
	$(CC) $(STD) $(WARN) $(ASAN) -o $(BUILD)/poc_sender_asan sender/poc_sender.c
	$(CC) $(STD) $(WARN) $(ASAN) -o $(BUILD)/poc_receiver_asan receiver-c/poc_receiver.c

clean:
	rm -rf $(BUILD) results
