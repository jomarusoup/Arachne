---
name: data-throughput-accelerator
description: 대량 데이터 처리, queue, batch, streaming, DB write, network I/O 경로의 처리량 병목을 측정하고 개선하는 스킬.
---

# Data Throughput Accelerator

처리량이 중요한 데이터 경로를 측정하고 개선한다.

## 언제 사용하나

- ingest worker, ETL, queue consumer, batch job이 느릴 때
- DB write throughput이 부족할 때
- API fan-out, network I/O, serialization 비용이 클 때
- latency보다 total throughput과 backlog 감소가 중요할 때

## 측정 지표

- records/sec
- bytes/sec
- queue depth
- batch size
- retry count
- DB transaction time
- serialization/deserialization time
- CPU, memory, network, disk I/O

## 최적화 순서

1. 병목 구간을 계측한다.
2. batch 크기를 조정한다.
3. connection pool과 transaction 범위를 조정한다.
4. 불필요한 serialization과 copy를 줄인다.
5. hot path와 cold path를 분리한다.
6. backpressure와 retry jitter를 추가한다.
7. 실패한 record 재처리 정책을 분리한다.

## 검증

최적화 전후 같은 입력량, 같은 환경, 같은 지표로 비교한다.
처리량 개선이 데이터 손실, 중복 처리, 순서 보장 위반을 만들지 않았는지 확인한다.
