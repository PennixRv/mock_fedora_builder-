###
# 以Fedora38 x64 docker镜像为基础，添加对Fedora38 Riscv64 最小环境支持，添加镜像构建工具appliance-tools
###
FROM fedora:latest
LABEL maintainer="peng.fu@rivai.ai"

ARG proxy_ipv4="0.0.0.0"
ARG proxy_port="7890"

ENV DNF_PROXY=""

RUN if [ "${proxy_ipv4}" != "0.0.0.0" ]; then \
        echo "proxy=http://${proxy_ipv4}:${proxy_port}" >> /etc/dnf/dnf.conf; \
    fi && \
    dnf update -y && \
	dnf install -y util-linux mock wget qemu-system-riscv git vim qemu-user-static && \
	adduser riscv && \
	echo "riscv ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
	usermod -aG root riscv && \
	usermod -aG mock riscv
USER riscv
RUN cd ${HOME} && cat >> ./fedora-38-riscv64.cfg <<EOF
config_opts['target_arch'] = 'riscv64'
config_opts['legal_host_arches'] = ('riscv64',)
config_opts['qemu_user_static_mapping'] = {
    'riscv64': 'riscv64',
}
config_opts['dev_loop_count'] = 64
config_opts['macros']['%_smp_mflags'] = "-j20"
config_opts['use_bootstrap'] = True
config_opts['dnf_install_command'] = 'makecache'
config_opts['system_dnf_command'] = '/usr/bin/dnf'
config_opts['cleanup_on_success'] = True
config_opts['cleanup_on_failure'] = True
config_opts['package_manager_max_attempts'] = 2
config_opts['package_manager_attempt_delay'] = 10

config_opts['http_proxy']  = os.getenv("http_proxy")
config_opts['https_proxy'] = os.getenv("https_proxy")
config_opts['docker_host'] = os.getenv("DOCKER_HOST")

config_opts['releasever'] = '38'
config_opts['root'] = 'rivai-fedora-{{ releasever }}-{{ target_arch }}'
config_opts['mirrored'] = config_opts['target_arch'] != 'i686'
config_opts['chroot_setup_cmd'] = 'install @{% if mirrored %}buildsys-{% endif %}build'
config_opts['dist'] = 'fc{{ releasever }}'
config_opts['extra_chroot_dirs'] = [ '/run/lock', ]

config_opts['package_manager'] = 'dnf'
config_opts['dnf.conf'] = """

[main]
keepcache=1
debuglevel=2
reposdir=/dev/null
logfile=/var/log/yum.log
retries=20
obsoletes=1
gpgcheck=0
assumeyes=1
syslog_ident=mock
syslog_device=
install_weak_deps=0
metadata_expire=0
best=1
module_platform_id=platform:f38
protected_packages=
user_agent=

{%- macro rawhide_gpg_keys() -%}
file:///usr/share/distribution-gpg-keys/fedora/RPM-GPG-KEY-fedora-$releasever-primary
{%- for version in [releasever|int, releasever|int - 1]
%} file:///usr/share/distribution-gpg-keys/fedora/RPM-GPG-KEY-fedora-{{ version }}-primary
{%- endfor %}
{%- endmacro %}

# repos

[Openkoji_Kojifiles_Repos_F38-build]
name=Openkoji_Kojifiles_Repos_F38-build
baseurl=http://openkoji.iscas.ac.cn/kojifiles/repos/f38-build/latest/riscv64/
cost=2000
enabled=1
skip_if_unavailable=True

[Openkoji_Kojifiles_Repos_F38-build-side-42-init-devel]
name=Openkoji_Kojifiles_Repos_F38-build-side-42-init-devel
baseurl=http://openkoji.iscas.ac.cn/kojifiles/repos/f38-build-side-42-init-devel/latest/riscv64/
cost=2000
enabled=1
skip_if_unavailable=True

[Openkoji_Repos_F38dist]
name=Openkoji_Repos_F38dist
baseurl=http://openkoji.iscas.ac.cn/repos/fc38dist/riscv64/
cost=2000
enabled=1
skip_if_unavailable=True

[Openkoji_Repos_Fc38-noarches-repo]
name=Openkoji_Repos_Fc38-noarches-repo
baseurl=http://openkoji.iscas.ac.cn/repos/fc38-noarches-repo/riscv64/
cost=2000
enabled=1
skip_if_unavailable=True

[Openkoji_Pub_temp-f38-repo]
name=Openkoji_Pub_temp-f38-repo
baseurl=https://openkoji.iscas.ac.cn/pub/temp-f38-repo/riscv64/
cost=2000
enabled=1
skip_if_unavailable=True

[Openkoji_Pub_temp-python311-repo]
name=Openkoji_Pub_temp-python311-repo
baseurl=http://openkoji.iscas.ac.cn/pub/temp-python311-repo/riscv64/
cost=2000
enabled=1
skip_if_unavailable=True

[fedora_riscv_rocks-repos_f38-build]
name=fedora_riscv_rocks-repos_f38-build
baseurl=http://fedora.riscv.rocks/repos/f38-build/latest/riscv64/
cost=2000
enabled=0
skip_if_unavailable=True

[fedora_riscv_rocks-repos_f38-build]
name=fedora_riscv_rocks-repos_f38-build
baseurl=http://fedora.riscv.rocks/repos/f38-build/latest/riscv64/
cost=2000
enabled=0
skip_if_unavailable=True

[fedora_riscv_rocks-repos-dist_f38]
name=fedora_riscv_rocks-repos-dist_f38
baseurl=http://fedora.riscv.rocks/repos-dist/f38/latest/riscv64/
cost=2000
enabled=0
skip_if_unavailable=True

[fedora_riscv_rocks-kojifiles_repos-dist_f38]
name=fedora_riscv_rocks-kojifiles_repos-dist_f38
baseurl=http://fedora.riscv.rocks/kojifiles/repos-dist/f38/latest/riscv64/
cost=2000
enabled=0
skip_if_unavailable=True

[fedora_riscv_rocks-kojifiles_repos_f38-build]
name=fedora_riscv_rocks-kojifiles_repos_f38-build
baseurl=http://fedora.riscv.rocks/kojifiles/repos/f38-build/latest/riscv64/
cost=2000
enabled=0
skip_if_unavailable=True

"""
EOF
WORKDIR /home/riscv
USER riscv

