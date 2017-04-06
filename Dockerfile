FROM yastdevel/ruby
COPY . /usr/src/app

# temporary to use the last packaging tasks
# TODO: remove when it will be in openSUSE:Factory
RUN gem install packaging_rake_tasks
