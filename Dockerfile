FROM centos

# Add yarn repo
RUN curl -sL https://dl.yarnpkg.com/rpm/yarn.repo | tee /etc/yum.repos.d/yarn.repo
# Install nodejs/npm/yarn
RUN curl --silent --location https://rpm.nodesource.com/setup_8.x | bash -

RUN yum install -y epel-release && yum install -y git jq nodejs patch sudo yarn

RUN curl -sSL -o /usr/local/bin/umoci https://github.com/openSUSE/umoci/releases/download/v0.4.2/umoci.amd64 && chmod +x /usr/local/bin/umoci
RUN curl -sSL -o /usr/local/bin/runc https://github.com/opencontainers/runc/releases/download/v1.0.0-rc5/runc.amd64 && chmod +x /usr/local/bin/runc

RUN yum -y install \
    make \
    golang \
    bats \
    btrfs-progs-devel \
    device-mapper-devel \
    glib2-devel \
    gpgme-devel \
    libassuan-devel \
    libseccomp-devel \
    ostree-devel \
    bzip2 \
    go-md2man \
    skopeo-containers \
    skopeo

RUN yum -y install automake \
                   autoconf \
                   gettext-devel \
                   libtool \
                   libxslt \
                   libsemanage-devel \
                   bison \
                   libcap-devel \
                   podman

RUN cd /tmp/ && \
    git clone https://github.com/shadow-maint/shadow && \
    cd shadow && \
    ./autogen.sh --prefix=/usr --enable-man && \
    make && \
    sudo make -C src install && \
    rm -rf /tmp/shadow

# RUN cd /tmp && \
#     git clone https://github.com/rootless-containers/slirp4netns.git && \
#     cd slirp4netns && \
#     ./autogen.sh && \
#     ./configure --prefix=/usr && \
#     make -j $(nproc) && \
#     sudo make install && \
#     ru -rf /tmp/slirp4netns

RUN mkdir /tmp/buildah && \
  cd /tmp/buildah && \
  export GOPATH=`pwd` && \
  git clone https://github.com/containers/buildah ./src/github.com/containers/buildah && \
  cd ./src/github.com/containers/buildah && \
  make  && \
  make install && \
  rm -rf /tmp/buildah

RUN curl -Lo /tmp/openshift-origin-client-tools.tar.gz https://github.com/openshift/origin/releases/download/v3.11.0/openshift-origin-client-tools-v3.11.0-0cbc58b-linux-64bit.tar.gz
RUN tar --strip 1 -zxf /tmp/openshift-origin-client-tools.tar.gz -C /usr/local/bin && rm -f /tmp/openshift-origin-client-tools.tar.gz


ENV NODEJS_VERSION=6 \
    NPM_RUN=start \
    NPM_CONFIG_PREFIX=$HOME/.npm-global

COPY ["docker_build.sh","/usr/local/bin/docker_build"]
COPY ["publish_plugin.sh", "/usr/local/bin/publish_plugin"]

WORKDIR /projects

# Create root node_modules in order to not use node_modules in each project folder
RUN mkdir /node_modules /umoci_images

# The following instructions set the right
# permissions and scripts to allow the container
# to be run by an arbitrary user (i.e. a user
# that doesn't already exist in /etc/passwd)
# Adding user to the 'root' is a workaround for https://issues.jboss.org/browse/CDK-305
RUN echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    useradd -u 1000 -G users,wheel,root -d /home/user --shell /bin/bash -m user && \
    usermod -p "*" user && \
    # Defines the root /node_modules as the folder to use by yarn
    echo '"--*.modules-folder" "/node_modules"' > /home/user/.yarnrc && \
    touch /etc/subuid && \
    touch /etc/subgid

USER user

ENV HOME /home/user
RUN for f in "/home/user" "/etc/passwd" "/etc/group" "/etc/subuid" "/etc/subgid" "/projects" "/node_modules" "/umoci_images"; do\
           sudo chgrp -R 0 ${f} && \
           sudo chmod -R g+rwX ${f}; \
        done && \
        # Generate passwd.template \
        cat /etc/passwd | \
        sed s#user:x.*#user:x:\${USER_ID}:\${GROUP_ID}::\${HOME}:/bin/bash#g \
        > /home/user/passwd.template && \
        # Generate group.template \
        cat /etc/group | \
        sed s#root:x:0:#root:x:0:0,\${USER_ID}:#g \
        > /home/user/group.template && \
        echo \${USER_ID}:110000:65536 > /home/user/subuid.template && \
        echo \${USER_ID}:110000:65536 > /home/user/subgid.template

# RUN sudo echo 10000 > /proc/sys/user/max_user_namespaces

RUN git clone https://github.com/cyphar/orca-build.git && \
            cd  orca-build && \
            sudo make install

COPY ["/tests/","/tests/"]
COPY ["entrypoint.sh","/home/user/entrypoint.sh"]
ENTRYPOINT ["/home/user/entrypoint.sh"]
CMD tail -f /dev/null