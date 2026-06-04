#!/bin/bash
################################################################################
# FILE NAME   : tmux.sh
# DESCRIPTION : tmux 세션 생성·접속·삭제를 메뉴로 관리하는 워크스페이스 매니저
# DATA        : 2026-06-03
# Modification: 2026-06-03
################################################################################
set -euo pipefail

# tmux 설치 확인
if ! command -v tmux &>/dev/null; then
    echo "[ERROR] tmux가 설치되어 있지 않습니다." >&2
    exit 1
fi

# 색상 정의 (CLI 가독성용)
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 사용법 출력 함수
show_help() {
    clear
    echo -e "${BLUE}====================================================${NC}"
    echo -e "         TMUX WORKSPACE MANAGER 사용법 안내         "
    echo -e "${BLUE}====================================================${NC}"
    echo -e "${YELLOW}1. 세션 내부 필수 단축키 (가장 중요)${NC}"
    echo -e "   세션에 접속한 상태에서는 모든 명령 앞에 ${GREEN}Ctrl + b${NC} (Prefix)를 누릅니다."
    echo -e "   * 세션 탈출 (Detach) : ${GREEN}Ctrl + b${NC} 누른 후 ${GREEN}d${NC} (작업은 백그라운드 유지)"
    echo -e "   * 세션 내 검색/스크롤 : ${GREEN}Ctrl + b${NC} 누른 후 ${GREEN}[${NC} (방향키/마우스휠로 이동, 나갈땐 q)"
    echo -e ""
    echo -e "${YELLOW}2. 화면 분할 세션 (테스트/모니터링 템플릿) 조작${NC}"
    echo -e "   * 화면 좌우 분할 : ${GREEN}Ctrl + b${NC} 누른 후 ${GREEN}%${NC}"
    echo -e "   * 화면 상하 분할 : ${GREEN}Ctrl + b${NC} 누른 후 ${GREEN}\"${NC}"
    echo -e "   * 분할된 창 간 이동 : ${GREEN}Ctrl + b${NC} 누른 후 ${GREEN}방향키${NC} (왼쪽/오른쪽/위/아래)"
    echo -e "   * 현재 창 최대화/복원 : ${GREEN}Ctrl + b${NC} 누른 후 ${GREEN}z${NC}"
    echo -e "   * 현재 분할 창만 닫기 : ${GREEN}Ctrl + b${NC} 누른 후 ${GREEN}x${NC}"
    echo -e ""
    echo -e "${YELLOW}3. 매니저 팁${NC}"
    echo -e "   * Claude Code 세션은 진입하자마자 에이전트가 자동 실행됩니다."
    echo -e "   * 터미널 창이 강제로 닫혀도 서버가 켜져 있다면 작업 내용은 안전합니다."
    echo -e "${BLUE}====================================================${NC}"
    read -rp "엔터를 누르면 메인 메뉴로 돌아갑니다..."
}

while true; do
    clear
    echo -e "${BLUE}====================================================${NC}"
    echo -e "      CLI TMUX WORKSPACE MANAGER (Claude Code)      "
    echo -e "${BLUE}====================================================${NC}"
    echo -e " [1] 신규 세션 추가 (템플릿 선택)"
    echo -e " [2] 세션 목록 보기 및 즉시 접속 (Attach)"
    echo -e " [3] 세션 선택 삭제 (Kill)"
    echo -e " [4] 모든 세션 일괄 종료"
    echo -e " [5] 매니저 및 단축키 사용법 보기"
    echo -e " [0] 매니저 나가기"
    echo -e "${BLUE}====================================================${NC}"
    echo -e " -> 필수: 세션 탈출은 ${YELLOW}[Ctrl + b] 누른 후 [d]${NC}"
    echo -e "${BLUE}----------------------------------------------------${NC}"
    
    # 현재 활성화된 세션 간략하게 미리 보여주기
    echo -e "${YELLOW}<< 현재 실행 중인 tmux 세션 목록 >>${NC}"
    if ! tmux ls 2>/dev/null; then
        echo -e "  [실행 중인 세션이 없습니다]"
    fi
    echo -e "${BLUE}----------------------------------------------------${NC}"
    
    read -p "선택할 기능의 숫자를 입력하세요: " main_choice

    case $main_choice in
        1) # 1. 신규 세션 추가
            echo ""
            read -p "새 세션 이름을 입력하세요 (영문 추천): " sname
            if [ -z "$sname" ]; then
                echo -e "${RED}오류: 세션 이름은 비어둘 수 없습니다.${NC}"
                sleep 1
                continue
            fi

            if [[ ! "$sname" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                echo -e "${RED}오류: 영문, 숫자, _, - 만 사용하세요.${NC}"
                sleep 2
                continue
            fi
            
            # 이미 존재하는 세션인지 체크
            if tmux has-session -t "$sname" 2>/dev/null; then
                echo -e "${RED}오류: 이미 '$sname' 세션이 존재합니다.${NC}"
                sleep 2
                continue
            fi

            echo -e "\n${YELLOW}어떤 작업 환경으로 셋업하시겠습니까?${NC}"
            echo "1) 기본 터미널형"
            echo "2) Claude Code 자동 실행형 (dev)"
            echo "3) 테스트/모니터링용 (화면 좌우 분할)"
            read -p "템플릿 번호 선택: " t_choice

            case $t_choice in
                2)
                    tmux new-session -d -s "$sname" -c "$(pwd)"
                    tmux send-keys -t "$sname" "claude" C-m
                    echo -e "${GREEN}>> Claude Code가 탑재된 '$sname' 세션이 생성되었습니다.${NC}"
                    ;;
                3)
                    tmux new-session -d -s "$sname" -c "$(pwd)"
                    tmux split-window -h -t "$sname" -c "$(pwd)"
                    echo -e "${GREEN}>> 화면이 2분할된 테스트용 '$sname' 세션이 생성되었습니다.${NC}"
                    ;;
                *)
                    tmux new-session -d -s "$sname" -c "$(pwd)"
                    echo -e "${GREEN}>> 기본 '$sname' 세션이 생성되었습니다.${NC}"
                    ;;
            esac
            sleep 2
            ;;

        2) # 2. 목록 출력 및 선택 접속
            echo ""
            IFS=$'\n' read -r -d '' -a sessions < <(tmux list-sessions -F "#S" 2>/dev/null && printf '\0')
            
            if [ ${#sessions[@]} -eq 0 ]; then
                echo -e "${RED}접속할 수 있는 세션이 없습니다.${NC}"
                sleep 2
                continue
            fi

            echo -e "${YELLOW}접속할 세션의 번호를 선택하세요:${NC}"
            select s_target in "${sessions[@]}" "이전 메뉴로 돌아가기"; do
                if [ "$s_target" == "이전 메뉴로 돌아가기" ] || [ -z "$s_target" ]; then
                    break
                fi
                echo -e "${GREEN}'$s_target' 세션으로 연결합니다...${NC}"
                sleep 0.5
                tmux attach -t "$s_target"
                break
            done
            ;;

        3) # 3. 세션 선택 삭제
            echo ""
            IFS=$'\n' read -r -d '' -a sessions < <(tmux list-sessions -F "#S" 2>/dev/null && printf '\0')
            
            if [ ${#sessions[@]} -eq 0 ]; then
                echo -e "${RED}삭제할 세션이 없습니다.${NC}"
                sleep 2
                continue
            fi

            echo -e "${RED}삭제할 세션의 번호를 선택하세요:${NC}"
            select s_kill in "${sessions[@]}" "이전 메뉴로 돌아가기"; do
                if [ "$s_kill" == "이전 메뉴로 돌아가기" ] || [ -z "$s_kill" ]; then
                    break
                fi
                
                read -p "[-] 정말 '$s_kill' 세션을 강제 종료하시겠습니까? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    tmux kill-session -t "$s_kill"
                    echo -e "${GREEN}'$s_kill' 세션이 닫혔습니다.${NC}"
                else
                    echo -e "${YELLOW}삭제가 취소되었습니다.${NC}"
                fi
                break
            done
            sleep 2
            ;;

        4) # 4. 일괄 종료
            echo ""
            read -p "[-] 백그라운드의 모든 tmux 세션을 종료하시겠습니까? (y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                tmux kill-server 2>/dev/null
                echo -e "${GREEN}모든 세션이 깔끔하게 정리되었습니다.${NC}"
            else
                echo -e "${YELLOW}취소되었습니다.${NC}"
            fi
            sleep 2
            ;;

        5) # 5. 사용법 출력
            show_help
            ;;

        0) # 종료
            echo -e "${YELLOW}매니저를 종료합니다. (백그라운드 세션들은 그대로 유지됩니다)${NC}"
            exit 0
            ;;

        *)
            echo -e "${RED}잘못된 입력입니다. 0~5 사이의 숫자를 입력해 주세요.${NC}"
            sleep 1
            ;;
    esac
done

