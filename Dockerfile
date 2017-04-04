FROM yastdevel/ruby
COPY . /usr/src/app
RUN zypper --gpg-auto-import-keys --non-interactive in --no-recommends osc build sudo
COPY .oscrc /root/
