FROM yastdevel/cpp:sle15-sp1
RUN zypper --gpg-auto-import-keys --non-interactive in --no-recommends \
  yast2-testsuite \
  yast2-pam \
  libnsl-devel \
  libtirpc-devel

COPY . /usr/src/app

