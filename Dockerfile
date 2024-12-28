FROM ruby:3.2.2

RUN apt-get update -qq && apt-get install -y build-essential nodejs

WORKDIR /app

COPY . .

RUN gem install bundler -v 2.5.11 && bundle install

EXPOSE 3000

CMD ["bundle", "exec", "resque-pool"]

