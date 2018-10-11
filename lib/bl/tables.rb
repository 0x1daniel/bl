# MIT License
#
# Copyright (c) 2018 Daniel Oltmanns
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
module Bl
  module Tables
    USERS = <<-SQL
    CREATE TABLE IF NOT EXISTS users (
      user_id bigserial NOT NULL,
      fullname varchar(100) NOT NULL,
      username varchar(10) NOT NULL,
      password varchar(100) NOT NULL,
      github varchar(30) NOT NULL,
      email varchar(100) NOT NULL,
      bio varchar(140) NOT NULL,
      UNIQUE(username),
      PRIMARY KEY(user_id)
    )
    SQL

    ARTICLES = <<-SQL
    CREATE TABLE IF NOT EXISTS articles (
      article_id bigserial NOT NULL,
      author bigserial REFERENCES users(user_id) ON DELETE CASCADE,
      slug varchar(60) NOT NULL,
      title varchar(60) NOT NULL,
      abstract text NOT NULL,
      content text NOT NULL,
      created_date integer DEFAULT extract(epoch from now() at time zone 'utc' at time zone 'utc'),
      last_change integer DEFAULT extract(epoch from now() at time zone 'utc' at time zone 'utc'),
      is_draft boolean DEFAULT 'true',
      UNIQUE(slug),
      PRIMARY KEY(article_id)
    )
    SQL
  end
end
