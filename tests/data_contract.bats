#!/usr/bin/env bats
################################################################################
# FILE NAME   : data_contract.bats
# DESCRIPTION : DB·JSON 데이터 계약 quality gate — python-db fixture의 정적 계약은
#               모든 플랫폼에서, 실행 검증(alembic·pytest)은 uv 가용 시 수행
# DATA        : 2026-06-11
# Modification: 2026-06-11
################################################################################

#===============================================================================
# FUNCTION    : setup_file
# DESCRIPTION : 파일 단위 1회 준비 — uv 가용 시 fixture를 임시 디렉터리로 복사해
#               의존성 동기화 (저장소 트리 오염 방지)
#===============================================================================
setup_file() {
    REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export REPO_DIR
    export FIXTURE_DIR="${REPO_DIR}/tests/fixtures/python-db"

    if command -v uv >/dev/null 2>&1; then
        export RUN_DIR="${BATS_FILE_TMPDIR}/python-db"
        cp -R "$FIXTURE_DIR" "$RUN_DIR"
        git -C "$RUN_DIR" init -q
        (cd "$RUN_DIR" && uv sync -q)
    fi
}

#===============================================================================
# FUNCTION    : require_uv
# DESCRIPTION : uv 없는 환경에서 실행 검증 테스트를 skip 처리
#===============================================================================
require_uv() {
    command -v uv >/dev/null 2>&1 \
        || skip "uv 없음 — 실행 검증 생략 (정적 계약 검사만 수행)"
}

#-------------------------------------------------------------------------------
# 정적 계약 — 모든 CI 플랫폼에서 수행
#-------------------------------------------------------------------------------
@test "data contract: fixture 필수 구조 존재" {
    [ -f "${FIXTURE_DIR}/pyproject.toml" ]
    [ -f "${FIXTURE_DIR}/alembic.ini" ]
    [ -f "${FIXTURE_DIR}/alembic/env.py" ]
    [ -f "${FIXTURE_DIR}/alembic/versions/0001_create_users.py" ]
    [ -f "${FIXTURE_DIR}/alembic/versions/0002_create_orders.py" ]
    [ -f "${FIXTURE_DIR}/app/models.py" ]
    [ -f "${FIXTURE_DIR}/app/classification.py" ]
    [ -f "${FIXTURE_DIR}/app/schemas.py" ]
    [ -f "${FIXTURE_DIR}/app/contract.py" ]
    [ -f "${FIXTURE_DIR}/app/service.py" ]
    [ -x "${FIXTURE_DIR}/.arachne/verify.sh" ]
    [ -f "${FIXTURE_DIR}/.arachne/commands" ]
}

@test "data contract: revision 체인 일관성 — 0002 가 0001 을 따른다" {
    rev1=$(sed -n 's/^revision = "\(.*\)"$/\1/p' \
        "${FIXTURE_DIR}/alembic/versions/0001_create_users.py")
    down2=$(sed -n 's/^down_revision = "\(.*\)"$/\1/p' \
        "${FIXTURE_DIR}/alembic/versions/0002_create_orders.py")
    [ -n "$rev1" ]
    [ "$rev1" = "$down2" ]
}

@test "data contract: downgrade 는 forward-fix 원칙을 명시" {
    grep -q "NotImplementedError" \
        "${FIXTURE_DIR}/alembic/versions/0001_create_users.py"
    grep -q "forward-fix" \
        "${FIXTURE_DIR}/alembic/versions/0002_create_orders.py"
}

@test "data contract: schema snapshot 은 유효한 JSON + 필수 필드 포함" {
    snapshot="${FIXTURE_DIR}/tests/data_contract/snapshots/order_out.schema.json"
    [ -f "$snapshot" ]
    run jq -e '.amount.type == "Decimal" and .created_at.type == "datetime"' \
        "$snapshot"
    [ "$status" -eq 0 ]
}

@test "data contract: .arachne/commands 에 migration·pytest 게이트 포함" {
    grep -qF "alembic upgrade head" "${FIXTURE_DIR}/.arachne/commands"
    grep -qF "pytest tests/data_contract" "${FIXTURE_DIR}/.arachne/commands"
}

@test "data contract: fixture 는 합성 데이터만 사용 (실제 PII 패턴 없음)" {
    run bash -c "grep -rhoE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' \
        '${FIXTURE_DIR}/app' '${FIXTURE_DIR}/tests' | grep -v '@example\.com'"
    [ "$status" -ne 0 ]
}

#-------------------------------------------------------------------------------
# 실행 검증 — uv 가용 환경에서만 (GitHub CI verify-data-contract job)
#-------------------------------------------------------------------------------
@test "data contract: 빈 DB → alembic upgrade head 성공" {
    require_uv
    run bash -c "cd '$RUN_DIR' && rm -f empty.db \
        && DATABASE_URL='sqlite:///./empty.db' uv run alembic upgrade head \
        && DATABASE_URL='sqlite:///./empty.db' uv run python -c \"
import sqlalchemy as sa
names = sa.inspect(sa.create_engine('sqlite:///./empty.db')).get_table_names()
assert 'users' in names and 'orders' in names, names
\""
    [ "$status" -eq 0 ]
}

@test "data contract: 이전 revision DB → upgrade head 성공" {
    require_uv
    run bash -c "cd '$RUN_DIR' && rm -f prev.db \
        && DATABASE_URL='sqlite:///./prev.db' uv run alembic upgrade 0001_create_users \
        && DATABASE_URL='sqlite:///./prev.db' uv run alembic upgrade head"
    [ "$status" -eq 0 ]
}

@test "data contract: rollback·idempotency·snapshot·PII pytest 게이트 green" {
    require_uv
    run bash -c "cd '$RUN_DIR' && uv run pytest tests/data_contract -q"
    [ "$status" -eq 0 ]
}

@test "data contract: project-check 가 fixture 전체 게이트를 실행" {
    require_uv
    run bash "${REPO_DIR}/install.sh" --project-check "$RUN_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *"모든 프로젝트 검증 통과"* ]]
}
