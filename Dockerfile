FROM ruby:alpine

RUN apk add --update build-base git ruby-dev postgresql-dev
ENV APP /src/app

ADD . $APP
RUN cd $APP && bundle install --without test development
WORKDIR $APP