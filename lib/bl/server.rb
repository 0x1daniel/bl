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
require 'sinatra/base'
require 'argon2'

module Bl
  class Server < Sinatra::Base
    # Cofniguration
    configure do
      # Allow external access
      set :bind, '0.0.0.0'
      # Set listening port
      set :port, 3000
      # Set views directory
      set :views, 'views'
      # Load config file
      set :config, Bl::Config.parse['bl']
      # Specify db field
      set :db, nil
      # Configure cookie session
      use Rack::Session::Cookie, :key => 'bl.session', :path => '/', :secret => config['secrets']['session']
    end

    # Middleware
    before do
      # Check if middleware is required
      return unless request.path.start_with?('/board')
      # Read session values
      @auth = session[:auth]
      @user_id = session[:user_id] if @auth
      # Read flash message
      @flash = session[:flash]
      session[:flash] = nil
    end

    # Assets
    get '/assets/style.css' do
      send_file 'static/style.css'
    end

    get '/assets/style.board.css' do
      send_file 'static/style.board.css'
    end

    get '/assets/script.js' do
      send_file 'static/script.js'
    end

    # GET routes
    get '/' do
      # Read page parameter
      page = (params[:page]) ? params[:page].to_i : 0
      # Read per page parameter
      per_page = (params[:per_page]) ? params[:per_page].to_i : 10
      # Get article records
      articles = db.get_articles_published(
        offset: page * per_page, limit: per_page
      )
      # Get count of all articles
      articles_count = db.get_articles_published_count
      # Generate pagination
      pagination = Pagination.generate(
        per_page: per_page, page: page, count: articles_count
      )
      erb :index, :locals => {
        articles: articles,
        page: page,
        pagination: pagination
      }
    end

    get '/article/:slug' do |slug|
      # Get article record
      article = db.get_article_published_by_slug(slug: slug)
      erb :'article/index', :locals => {
        article: article,
        back_url: (back == to("/article/#{article['slug']}")) ? '/' : back
      }
    end

    get '/board' do
      require_user
      erb :'board/index', :layout => :'board/layout'
    end

    get '/board/login' do
      require_secret
      require_guest
      erb :'board/login', :layout => :'board/layout'
    end

    get '/board/logout' do
      require_user
      # Clear session
      session.clear
      # Redirect
      redirect '/'
    end

    get '/board/article/:slug' do |slug|
      require_user
      # Get article record
      article = db.get_article_draft_or_published_by_slug(slug: slug)
      erb :'board/article/index', :layout => :'board/layout', :locals => {
        article: article,
        back_url: (back == to("/board/article/#{article['slug']}")) ? '/board/articles' : back
      }
    end

    get '/board/article/:slug/make_publish' do |slug|
      require_user
      # Update article record
      db.update_article_is_published slug: slug
      # New flash message
      new_flash 'success', 'article published'
      # Redirect
      redirect "/board/article/#{slug}"
    end

    get '/board/article/:slug/make_draft' do |slug|
      require_user
      # Update article record
      db.update_article_is_draft slug: slug
      # New flash message
      new_flash 'success', 'article drafted'
      # Redirect
      redirect "/board/article/#{slug}"
    end

    get '/board/articles' do
      require_user
      # Read page parameter
      page = (params[:page]) ? params[:page].to_i : 0
      # Read per page parameter
      per_page = (params[:per_page]) ? params[:per_page].to_i : 10
      # Get article records
      articles = db.get_articles_draft_or_published(
        offset: page * per_page, limit: per_page
      )
      # Get count of all articles
      articles_count = db.get_articles_draft_or_published_count
      # Generate pagination
      pagination = Pagination.generate(
        per_page: per_page, page: page, count: articles_count
      )
      erb :'board/articles/index', :layout => :'board/layout', :locals => {
        articles: articles,
        page: page,
        pagination: pagination
      }
    end

    get '/board/articles/add' do
      require_user
      erb :'board/articles/add', :layout => :'board/layout', :locals => {
        previous_article: session[:article]
      }
    end

    get '/board/articles/clear_previous' do
      require_user
      # Clear previous article from session
      session[:article] = nil
      redirect '/board/articles/add'
    end

    # POST routes
    post '/board/login' do
      require_secret
      require_guest
      # Get body data
      username = params[:username]
      password = params[:password]
      # Check data
      unless username.nil? || password.nil?
        # Get database record
        user = db.get_user_by_username(username: username)
        # Check password
        if user && Argon2::Password.verify_password(password, user['password'])
          # Update session details
          session[:auth] = true
          session[:user_id] = user['user_id']
          # Redirect
          redirect '/board'
          return
        end
      end
      # New error flash message
      new_flash 'error', 'wrong credentials'
      redirect "/board/login?secret=#{config['secret']}"
    end

    post '/board/articles' do
      require_secret
      require_user
      # Get body data
      slug = params[:slug]
      title = params[:title]
      abstract = params[:abstract]
      content = params[:content]
      draft = (params[:draft] == 'on')
      # Check data
      unless slug.nil? || title.nil? || abstract.nil? || content.nil?
        # Insert article into database
        db.create_new_article(
          author: session[:user_id], slug: slug, title: title,
          abstract: abstract, content: content, draft: draft
        )
        # New flash
        new_flash 'success', 'article published'
        # Redirect
        redirect '/board/articles'
        return
      end
      # New error flash
      new_flash 'error', 'wrong article details'
      # Store old article details in session
      session[:article] = {
        slug: slug, title: title, abstract: abstract, content: content,
        draft: draft
      }
      # Redirect
      redirect '/board/articles/add'
    end

    # Class internal helper functions
    private

    def config
      settings.config
    end

    def db
      settings.db
    end

    def new_flash(type, message)
      session[:flash] = {
        type: type,
        message: message
      }
    end

    def require_secret
      redirect '/' unless config['secrets']['access'] == params[:secret]
    end

    def require_guest
      redirect '/board' if @auth
    end

    def require_user
      redirect '/' unless @auth
    end
  end
end
