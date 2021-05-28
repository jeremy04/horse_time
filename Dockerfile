FROM ruby:2.6.7-alpine3.13

ENV ALPINE_MIRROR "http://dl-cdn.alpinelinux.org/alpine"
RUN echo "${ALPINE_MIRROR}/v3.13/main/" >> /etc/apk/repositories
RUN apk update && apk upgrade

RUN apk add --no-cache \
  nodejs \
  npm \
  build-base \
  --repository="${ALPINE_MIRROR}/v3.13/main/"

RUN node -v && npm -v && gem -v

RUN apk add --no-cache libxml2 libxslt && \
        apk add --no-cache --virtual .gem-installdeps build-base libxml2-dev libxslt-dev && \
        gem install nokogiri --version '~> 1.11.6' --platform=ruby -- --use-system-libraries && \
        rm -rf $GEM_HOME/cache && \
        apk del .gem-installdeps

RUN mkdir /app
WORKDIR /app

COPY Gemfile* /app

ENV BUNDLE_WITHOUT development test
RUN gem install bundler
RUN bundle install --jobs=3 
COPY . .
EXPOSE 4567

CMD bundle exec rackup -p 4567
