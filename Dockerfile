FROM yastdevel/cpp:sle12-sp4

RUN zypper --gpg-auto-import-keys --non-interactive in --no-recommends \
  yast2-testsuite \
  yast2-pam

COPY . /usr/src/app

