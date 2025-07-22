# 1. 스마트 공조기 구현

---

대한상공회의소 AI 시스템 반도체 SW 개발자 과정

Verilog(basys3)을 활용한 공조기, 전자레인지, 스톱워치 프로젝트

재작기간 : 2025.07.17 ~ 2025.07.25

---

## 1. 프로젝트 개요

- **다양한 센서(DHT11, 초음파)를 통해 실내 환경을 모니터링하고, 팬·문 제어 등 공조 시스템을 자동화하는 FPGA 기반 프로젝트**
- **UART 통신**을 통해 PC와 연동하여 실시간 상태 확인 및 수동 제어 가능

### < 핵심 목표 >

- 온도·습도·거리 센서 기반 자동 제어
- 사용자 수동 설정 지원 (온도, 팬 세기, 타이머)
- 거리 감지 기반 안전 정지(초음파 센서) + 경고음 출력(piezo 센서)
- UART 통신 기반 실시간 정보 확인

---

## 2. 사용 부품 및 구조

- **센서**: DHT11 (온습도), HC-SR04 (초음파 거리)
- **제어기**: Basys3 FPGA
- **출력장치**: DC 모터, 서보 모터, Piezo 버저
- **인터페이스**: 버튼, 스위치, UART (PC 연동)
- **디스플레이**: 7-segment

### [H/W] 형상



---

## 3. 시스템 동작 구조

### 모드별 FSM 구성

### ▶ 공조기 모드 (SW 기본값)

- FSM 기반: IDLE → AUTO → SET_TIME → SET_FUN → SET_TIMER

### ▶ 분초 시계 & 스톱워치 (SW1 ON)

- Clock FSM / Stopwatch FSM: `btnC`로 시작/정지 전환

### ▶ 전자레인지 모드 (SW2 ON)

- FSM: TIME_SET → COOKING → FINISHED / PAUSED

<img width="880" height="620" alt="1" src="https://github.com/user-attachments/assets/57adf620-24c0-4830-8e73-84b2a556cd2a" />


- main_top(Shematic)

<img width="846" height="380" alt="2" src="https://github.com/user-attachments/assets/bb3e3ddf-f47a-4449-81e1-63c471a6dc51" />


- block Diagram(공조기 모드)

<img width="851" height="425" alt="image (1)" src="https://github.com/user-attachments/assets/89afdc1d-a5ef-42cf-83ed-35f0e22bcd5f" />


---

## 🧠 핵심 모듈 설명

| 모듈명 | 기능 요약 |
| --- | --- |
| `main_top` | 세 가지 모드를 FSM으로 통합 및 MUX 전환 |
| `dht11` | 온습도 센서 신호 수신, 40bit 데이터 처리 및 패리티 검증 |
| `uart` | UART 송수신 FSM, 명령("A"/"M")에 따라 온습도/거리 응답 |
| `ultrasonic` | 초음파 trig, echo 신호 FSM 처리 후 거리 계산 |
| `display` | 센서 데이터와 모드 정보 표시 (7-segment 등) |

---

## 4. UART 동작 방식

- **"A" 입력 시** : 온습도 정보 전송
- **"M" 입력 시** : 거리 정보 전송
- FSM 기반 송수신 처리, step-by-step 문자 전송

<img width="1525" height="1162" alt="image (2)" src="https://github.com/user-attachments/assets/f51c6d5d-551e-44a8-8953-4f96c6d52442" />


---

## 5. 시연 영상 내용 (구성된 실제 동작)

1. 공조기 모드
2. 전자레인지 모드
3. 분초시계/스톱워치 모드
    
    (※ 각 모드 전환은 스위치로 FSM 전이)
    

---

## 6. 부록 요약 (디지털 논리 이론)

- **Tri-state**: High / Low / High-Z 상태
- **Synthesis vs Implementation**
    - Synthesis: 논리 최적화, 게이트 레벨로 변환
    - Implementation: 배치/배선, 타이밍 분석
- **Metastable / Glitch** 현상 및 해결법
- **Flip-Flop 종류**
    - D, JK, T 플립플롭 기능 및 사용처 요약

---

## 7. 결론 및 시사점

### < 배운 점 >

1. **단일 핀으로 입출력을 제어하는 DHT11 구현의 어려움**
2. **Implementation 단계에서 발생한 타이밍 이슈 해결 노력**
    - FSM 분리 구조 및 always 블록 개선 → 안정성 향상
3. **MUX 구조 설계의 중요성**
    - 세 모듈 통합 시 신호 충돌 방지를 위한 철저한 모드 분기

---

## < 마무리 >

본 프로젝트를 통해 **Verilog HDL 기반 FSM 설계, 센서 연동, 하드웨어 구조 통합, UART 통신 제어 등 임베디드 시스템의 핵심 요소를 모두 직접 구현하고 통합**하는 경험을 했습니다. 실제 적용 가능한 스마트 공조 시스템을 구성하며, **하드웨어와 소프트웨어 융합의 중요성**을 체득하였습니다.
