# Kubernetes 클러스터 Ansible 자동화

이 프로젝트는 Ansible을 사용해서 Kubernetes 클러스터를 자동으로 프로비저닝하는 도구입니다.

## 주요 개선사항

### 기존 문제점
- 마스터와 워커 노드마다 별도의 playbook 실행 필요
- 각 노드별로 개별적인 hostname 설정 role
- 수동으로 여러 번의 ansible-playbook 명령어 실행 필요

### 리팩토링 후 개선점
- **통합 playbook**: 한 번의 명령어로 전체 클러스터 설치
- **통합 hostname role**: 변수 기반 hostname 설정
- **태그 기반 실행**: 선택적으로 특정 노드 타입만 설치 가능
- **자동화 스크립트**: 연결 테스트, 오류 처리, 로깅 포함

## 파일 구조

```
kube/
├── setup_cluster.sh           # 메인 실행 스크립트
├── playbooks/
│   ├── cluster_setup.yaml     # 통합 클러스터 설치 playbook
│   ├── controller_setup.yaml  # 기존 마스터 노드 playbook (deprecated)
│   ├── compute1_setup.yaml    # 기존 워커1 playbook (deprecated)
│   └── compute2_setup.yaml    # 기존 워커2 playbook (deprecated)
├── inventory/
│   └── kube.yaml              # 개선된 inventory 구조
├── roles/
│   ├── set_hostname/          # 통합 hostname 설정 role
│   ├── common/                # 공통 설정
│   ├── controller/            # 마스터 노드 설정
│   ├── join/                  # 워커 노드 조인
│   └── ...                    # 기타 roles
└── ansible.cfg
```

## 사용 방법

### 1. 전체 클러스터 설치 (권장)

```bash
cd kube
./setup_cluster.sh
```

### 2. Rocky Linux에서 sudo 설정과 함께 설치

Rocky Linux를 사용하는 경우, passwordless sudo가 설정되지 않았다면:

```bash
# sudo 설정 후 클러스터 설치 (root 패스워드 필요)
./setup_cluster.sh -S -K

# 또는 sudo 설정만 먼저 실행
./setup_cluster.sh -S -K
# 그 후 클러스터 설치
./setup_cluster.sh
```

### 3. 특정 노드 타입만 설치

```bash
# 마스터 노드만 설치
./setup_cluster.sh -t master

# 워커 노드만 설치
./setup_cluster.sh -t worker

# 인프라 노드만 설치
./setup_cluster.sh -t infra
```

### 4. 드라이런 모드 (변경사항 미리보기)

```bash
./setup_cluster.sh -c
```

### 5. 자세한 로그 출력

```bash
./setup_cluster.sh -v
```

### 6. 기존 방식 (개별 playbook)

```bash
# 기존 방식 (더 이상 권장하지 않음)
ansible-playbook -i inventory/kube.yaml playbooks/controller_setup.yaml
ansible-playbook -i inventory/kube.yaml playbooks/compute1_setup.yaml  
ansible-playbook -i inventory/kube.yaml playbooks/compute2_setup.yaml
```

## Rocky Linux 사용자 설정

### 필수 조건
- `rocky` 사용자가 SSH 접근 가능
- SSH 키 기반 인증 설정 완료
- 초기 설정을 위한 root 접근 권한 (sudo 설정용)

### Inventory 구조

현재 inventory는 Rocky Linux 환경에 최적화되어 있습니다:

```yaml
all:
  vars:
    ansible_user: rocky                                    # Rocky 사용자
    ansible_ssh_private_key_file: /runner/ssh/ansible-ssh-key
    ansible_become: true                                   # sudo 사용
    ansible_become_method: sudo                           # sudo 방식
    ansible_become_user: root                             # root로 권한 상승
    ansible_python_interpreter: /usr/bin/python3         # Python3 사용
```

### Sudo 설정

Rocky Linux에서 `rocky` 사용자가 passwordless sudo를 사용할 수 있도록 자동 설정합니다:

1. **자동 sudo 설정**: `-S` 옵션 사용
2. **Wheel 그룹 추가**: rocky 사용자를 wheel 그룹에 추가
3. **Passwordless sudo**: `/etc/sudoers` 파일 수정
4. **권한 테스트**: sudo 권한 동작 확인

## Inventory 구조

새로운 inventory 구조는 계층적이고 확장 가능합니다:

```yaml
all:
  children:
    k8s_cluster:
      children:
        k8s_controller:     # 마스터 노드 그룹
        k8s_workers:        # 워커 노드 그룹
          children:
            k8s_compute1:
            k8s_compute2:
    k8s_infra:              # 인프라 노드 그룹
```

### 중요한 그룹명 규칙
- Ansible에서는 그룹명에 하이픈(`-`)을 사용할 수 없습니다
- 모든 그룹명에는 언더스코어(`_`)를 사용합니다
- 예: `k8s_controller`, `k8s_workers`, `k8s_compute1` 등

### 노드 추가 방법

새 워커 노드를 추가하려면:

1. `inventory/kube.yaml`에 새 노드 추가:
```yaml
k8s_compute3:
  hosts:
    compute3:
      ansible_host: 192.168.0.203
      node_hostname: node4.example.com
      node_role: worker
```

2. `k8s_workers` 그룹에 추가:
```yaml
k8s_workers:
  children:
    k8s_compute1:
    k8s_compute2:
    k8s_compute3:  # 새로 추가
```

## 스크립트 옵션

| 옵션 | 설명 | 예시 |
|------|------|------|
| `-h, --help` | 도움말 표시 | `./setup_cluster.sh -h` |
| `-i, --inventory` | inventory 파일 지정 | `./setup_cluster.sh -i custom-inventory.yaml` |
| `-c, --check` | 드라이런 모드 | `./setup_cluster.sh -c` |
| `-t, --tags` | 특정 태그만 실행 | `./setup_cluster.sh -t worker` |
| `-v, --verbose` | 자세한 출력 | `./setup_cluster.sh -v` |
| `-K, --ask-become-pass` | sudo 패스워드 입력 | `./setup_cluster.sh -K` |
| `-S, --setup-sudo` | sudo 설정 먼저 실행 | `./setup_cluster.sh -S` |

## 태그 시스템

| 태그 | 대상 | 설명 |
|------|------|------|
| `master`, `controller` | 마스터 노드 | Kubernetes 컨트롤 플레인 설치 |
| `worker`, `compute` | 워커 노드 | 워커 노드 설정 및 클러스터 조인 |
| `infra`, `infrastructure` | 인프라 노드 | 추가 인프라 서비스 |
| `verify`, `status` | 마스터 노드 | 클러스터 상태 확인 |

## 문제 해결

### 연결 실패 시
```bash
# SSH 연결 테스트
ansible all -i inventory/kube.yaml -m ping

# SSH 키 확인
ssh-add -l
```

### 부분 재설치
```bash
# 워커 노드만 다시 설치
./setup_cluster.sh -t worker

# 특정 노드만 재설치
ansible-playbook -i inventory/kube.yaml playbooks/cluster_setup.yaml --limit compute1
```

## 주요 이점

1. **단순화**: 한 번의 명령어로 전체 클러스터 설치
2. **유연성**: 태그를 사용한 선택적 설치
3. **확장성**: 새 노드 추가가 용이함
4. **안정성**: 연결 테스트 및 오류 처리 포함
5. **가시성**: 컬러 로그 및 진행 상황 표시 