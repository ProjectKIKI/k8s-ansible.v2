#!/bin/bash

# 프로젝트 디렉토리 생성
PROJECT_NAME=${ansible-test}
mkdir -p $PROJECT_NAME/{inventory,roles,playbooks}
mkdir -p $PROJECT_NAME/roles/common/{tasks,handlers,templates,files}

# ansible.cfg 생성
cat <<EOL > $PROJECT_NAME/ansible.cfg
[defaults]
inventory = ./inventory/hosts
remote_user = your-ssh-user
host_key_checking = False
retry_files_enabled = False
roles_path = ./roles
EOL

# inventory 파일 생성
cat <<EOL > $PROJECT_NAME/inventory/hosts
[all]
localhost ansible_connection=local
EOL

# 기본 역할 템플릿 생성
cat <<EOL > $PROJECT_NAME/roles/common/tasks/main.yml
- name: Install basic tools
  apt:
    name: "{{ item }}"
    state: present
  loop:
    - curl
    - git
EOL

# 기본 플레이북 생성
cat <<EOL > $PROJECT_NAME/playbooks/site.yml
- name: Apply common configuration
  hosts: all
  roles:
    - common
EOL

echo "Ansible 프로젝트 '$PROJECT_NAME'이 초기화되었습니다."