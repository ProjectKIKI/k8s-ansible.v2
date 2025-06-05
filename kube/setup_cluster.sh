#!/bin/bash

# Kubernetes 클러스터 전체 설치 스크립트
set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 기본 설정
INVENTORY_FILE="inventory/kube.yaml"
PLAYBOOK="playbooks/cluster_setup.yaml"
SUDO_PLAYBOOK="playbooks/setup_sudo.yaml"
ANSIBLE_CONFIG="ansible.cfg"

# 사용법 출력
usage() {
    echo "사용법: $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  -h, --help          이 도움말 표시"
    echo "  -i, --inventory     inventory 파일 지정 (기본값: $INVENTORY_FILE)"
    echo "  -c, --check         dry-run 모드로 실행"
    echo "  -t, --tags          특정 태그만 실행 (예: master, worker, infra)"
    echo "  -v, --verbose       자세한 출력"
    echo "  -K, --ask-become-pass  sudo 패스워드 입력 요청"
    echo "  -S, --setup-sudo    먼저 sudo 설정 실행"
    echo ""
    echo "예시:"
    echo "  $0                           # 전체 클러스터 설치"
    echo "  $0 -t master                 # 마스터 노드만 설치"
    echo "  $0 -t worker                 # 워커 노드만 설치"
    echo "  $0 -c                        # 드라이런 모드"
    echo "  $0 -v                        # 자세한 로그 출력"
    echo "  $0 -K                        # sudo 패스워드 입력"
    echo "  $0 -S                        # sudo 설정 후 클러스터 설치"
    echo "  $0 -S -K                     # sudo 패스워드로 sudo 설정 실행"
}

# 옵션 파싱
VERBOSE=""
CHECK_MODE=""
TAGS=""
ASK_BECOME_PASS=""
SETUP_SUDO=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -i|--inventory)
            INVENTORY_FILE="$2"
            shift 2
            ;;
        -c|--check)
            CHECK_MODE="--check"
            shift
            ;;
        -t|--tags)
            TAGS="--tags $2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE="-vvv"
            shift
            ;;
        -K|--ask-become-pass)
            ASK_BECOME_PASS="--ask-become-pass"
            shift
            ;;
        -S|--setup-sudo)
            SETUP_SUDO="true"
            shift
            ;;
        *)
            log_error "알 수 없는 옵션: $1"
            usage
            exit 1
            ;;
    esac
done

# 파일 존재 확인
check_files() {
    log_info "필요한 파일들 확인 중..."
    
    if [[ ! -f "$INVENTORY_FILE" ]]; then
        log_error "Inventory 파일이 없습니다: $INVENTORY_FILE"
        exit 1
    fi
    
    if [[ ! -f "$PLAYBOOK" ]]; then
        log_error "Playbook 파일이 없습니다: $PLAYBOOK"
        exit 1
    fi
    
    if [[ -n "$SETUP_SUDO" && ! -f "$SUDO_PLAYBOOK" ]]; then
        log_error "Sudo 설정 playbook이 없습니다: $SUDO_PLAYBOOK"
        exit 1
    fi
    
    if [[ ! -f "$ANSIBLE_CONFIG" ]]; then
        log_warning "ansible.cfg 파일이 없습니다. 기본 설정을 사용합니다."
    fi
    
    log_success "모든 필수 파일이 존재합니다."
}

# Ansible 연결 테스트
test_connection() {
    log_info "노드 연결 테스트 중..."
    
    if ansible all -i "$INVENTORY_FILE" -m ping $VERBOSE; then
        log_success "모든 노드 연결 성공"
    else
        log_error "일부 노드 연결 실패. SSH 키 및 네트워크 설정을 확인하세요."
        exit 1
    fi
}

# Sudo 권한 테스트
test_sudo() {
    log_info "sudo 권한 테스트 중..."
    
    # sudo 테스트 명령어 구성
    SUDO_TEST_CMD="ansible all -i $INVENTORY_FILE -m shell -a 'whoami' --become $VERBOSE"
    
    if [[ -n "$ASK_BECOME_PASS" ]]; then
        SUDO_TEST_CMD="$SUDO_TEST_CMD $ASK_BECOME_PASS"
    fi
    
    if eval "$SUDO_TEST_CMD" | grep -q "root"; then
        log_success "모든 노드에서 sudo 권한 확인됨"
    else
        log_warning "sudo 권한 테스트 실패. passwordless sudo가 설정되지 않았을 수 있습니다."
        log_info "만약 sudo 패스워드가 필요하다면 -K 옵션을 사용하세요."
        
        if [[ -z "$ASK_BECOME_PASS" ]]; then
            read -p "계속 진행하시겠습니까? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
}

# Sudo 설정 실행
setup_sudo() {
    log_info "Rocky 사용자 sudo 설정 실행 중..."
    
    SUDO_SETUP_CMD="ansible-playbook -i $INVENTORY_FILE $SUDO_PLAYBOOK $VERBOSE $ASK_BECOME_PASS"
    
    log_info "Sudo 설정 명령어: $SUDO_SETUP_CMD"
    
    if eval "$SUDO_SETUP_CMD"; then
        log_success "Sudo 설정이 완료되었습니다."
    else
        log_error "Sudo 설정 중 오류가 발생했습니다."
        exit 1
    fi
}

# 메인 실행
main() {
    log_info "Kubernetes 클러스터 설치를 시작합니다..."
    
    # 파일 확인
    check_files
    
    # Sudo 설정 (옵션이 있는 경우)
    if [[ -n "$SETUP_SUDO" ]]; then
        setup_sudo
        # sudo 설정 후 ASK_BECOME_PASS 제거 (이제 passwordless가 되어야 함)
        ASK_BECOME_PASS=""
        log_info "Sudo 설정 완료. passwordless sudo를 사용합니다."
    fi
    
    # 연결 테스트 (check 모드가 아닌 경우에만)
    if [[ -z "$CHECK_MODE" ]]; then
        test_connection
        test_sudo
    fi
    
    # Playbook 실행
    log_info "Ansible playbook 실행 중..."
    
    ANSIBLE_CMD="ansible-playbook -i $INVENTORY_FILE $PLAYBOOK $VERBOSE $CHECK_MODE $TAGS $ASK_BECOME_PASS"
    
    log_info "실행 명령어: $ANSIBLE_CMD"
    
    if eval "$ANSIBLE_CMD"; then
        log_success "클러스터 설치가 완료되었습니다!"
        
        if [[ -z "$CHECK_MODE" && -z "$TAGS" ]]; then
            log_info "클러스터 상태 확인을 위해 다음 명령어를 실행하세요:"
            echo "kubectl get nodes"
        fi
    else
        log_error "클러스터 설치 중 오류가 발생했습니다."
        exit 1
    fi
}

# 스크립트 실행
main "$@" 