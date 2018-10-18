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
require 'pg'
require 'argon2'
require_relative 'tables'
require_relative 'queries'

module Bl
  class Database
    def initialize
      # Load config values
      config = Config.parse['postgresql']
      # Connect to postgresql server
      @db = PG.connect(
        dbname: config['dbname'], host: config['host'], port: config['port'],
        user: config['user'], password: config['password']
      )
      # Ensure users table existence
      @db.exec Tables::USERS
      # Ensure articles table existence
      @db.exec Tables::ARTICLES
      # Ensure user queries to be prepared
      @db.prepare('new_user', Queries::NEW_USER)
      @db.prepare('get_user', Queries::GET_USER)
      @db.prepare('delete_user', Queries::DELETE_USER)
      # Prepare each update query option
      ['fullname', 'username', 'password', 'github', 'email', 'bio'].each do |f|
        # Construct query string
        query = Queries::UPDATE_USER.gsub(/\{FIELD\}/, f)
        # Prepare query
        @db.prepare("update_user:#{f}", query)
      end
      # Ensure articles queries to be prepared
      @db.prepare('new_article', Queries::NEW_ARTICLE)
      @db.prepare('get_articles_published', Queries::GET_ARTICLES_PUBLISHED)
      @db.prepare('get_articles_draft_or_published', Queries::GET_ARTICLES_DRAFT_OR_PUBLISHED)
      @db.prepare('get_articles_published_count', Queries::GET_ARTICLES_PUBLISHED_COUNT)
      @db.prepare('get_articles_draft_or_published_count', Queries::GET_ARTICLES_DRAFT_OR_PUBLISHED_COUNT)
      @db.prepare('get_article_draft_or_published_by_slug', Queries::GET_ARTICLE_DRAFT_OR_PUBLISHED_BY_SLUG)
      @db.prepare('get_article_published_by_slug', Queries::GET_ARTICLE_PUBLISHED_BY_SLUG)
    end

    # User functions
    def create_new_user(fullname:, username:, password:, github:, email:, bio:)
      # Hash password
      password = Argon2::Password.create password
      # Insert values and start execution
      @db.exec_prepared(
        'new_user',
        [fullname, username, password, github, email, bio]
      )
    end

    def update_user(username:, field:, value:)
      # Rehash password
      value = Argon2::Password.create(value) if field == 'password'
      # Insert values and start execution
      @db.exec_prepared("update_user:#{field}", [username, value])
    end

    def delete_user(username:)
      # Insert values and start execution
      @db.exec_prepared('delete_user', [username])
    end

    def get_user_by_username(username:)
      # Insert values and start execution
      results = @db.exec_prepared('get_user', [username])
      # Return if an record has been found
      return results[0] if results.ntuples == 1
    end

    # Article functions
    def create_new_article(author:, slug:, title:, abstract:, content:, draft:)
      # Insert values and start execution
      @db.exec_prepared(
        'new_article', [author, slug, title, abstract, content, draft]
      )
    end

    def get_article_draft_or_published_by_slug(slug:)
      # Insert values and start execution
      results = @db.exec_prepared(
        'get_article_draft_or_published_by_slug', [slug]
      )
      p results[0]
      # Return if an record has been found
      return results[0] if results.ntuples == 1
    end

    def get_article_published_by_slug(slug:)
      # Insert values and start execution
      results = @db.exec_prepared(
        'get_article_published_by_slug', [slug]
      )
      # Return if an record has been found
      return results[0] if results.ntuples == 1
    end

    def get_articles_published(offset: 0, limit: 25)
      puts "from #{offset} to #{limit}"
      # Insert values and start execution
      results = @db.exec_prepared('get_articles_published', [offset, limit])
      # Return if at least one record has been found
      return results if results.ntuples > 0
    end

    def get_articles_draft_or_published(offset: 0, limit: 25)
      # Insert values and start execution
      results = @db.exec_prepared(
        'get_articles_draft_or_published', [offset, limit]
      )
      # Return if at least one record has been found
      return results if results.ntuples > 0
    end

    def get_articles_published_count
      # Start execution
      results = @db.exec_prepared('get_articles_published_count')
      # Return single number
      return results[0]['count'].to_i
    end

    def get_articles_draft_or_published_count
      # Start execution
      results = @db.exec_prepared('get_articles_draft_or_published_count')
      # Return single number
      return results[0]['count'].to_i
    end
  end
end
