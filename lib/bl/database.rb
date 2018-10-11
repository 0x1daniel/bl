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
      # Ensure user queries to be prepared
      @db.prepare("new_user", Queries::NEW_USER)
      @db.prepare("get_user", Queries::GET_USER)
      @db.prepare("delete_user:", Queries::DELETE_USER)
      # Prepare each update query option
      ['fullname', 'username', 'password', 'github', 'email', 'bio'].each do |f|
        # Construct query string
        query = Queries::UPDATE_USER.gsub(/\{FIELD\}/, f)
        # Prepare query
        @db.prepare("update_user:#{f}", query)
      end
    end

    def create_new_user(fullname:, username:, password:, github:, email:, bio:)
      # Hash password
      password = Argon2::Password.create password
      # Prepare insert query for database
      @db.prepare("new_user:#{username}", Queries::NEW_USER)
      # Insert values and start execution
      @db.exec_prepared(
        "new_user:#{username}",
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
      # Prepare delete query for database
      @db.prepare("delete_user:#{username}", Queries::DELETE_USER)
      # Insert values and start execution
      @db.exec_prepared("delete_user:#{username}", [username])
    end

    def get_user_by_username(username:)
      # Insert values and start execution
      results = @db.exec_prepared("get_user", [username])
      # Return if an record has been found
      return results[0] if results.ntuples == 1
    end
  end
end
