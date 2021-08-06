FROM ruby:3.0.2-alpine

RUN apk update && apk --no-cache add tzdata git bash

COPY Gemfile* /tmp/

WORKDIR /tmp

RUN gem update bundler && bundle install -j 4 --full-index --without development test

WORKDIR /app
COPY . /app

CMD bundle exec clockwork clock.rb
