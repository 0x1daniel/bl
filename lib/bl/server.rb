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
    get '/assets/style.min.css' do
      send_file 'static/style.min.css'
    end

    get '/assets/style.board.min.css' do
      send_file 'static/style.board.min.css'
    end

    get '/assets/script.min.js' do
      send_file 'static/script.min.js'
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
      # 404 if article not found
      article_not_found if article.nil?
      erb :'article/index', :locals => {
        article: article,
        back_url: (back == to("/article/#{article['slug']}")) ? '/' : back
      }
    end

    get '/board' do
      require_user
      # Get dashboard statistics
      statistics = db.get_dashboard_statistics
      erb :'board/index', :layout => :'board/layout', :locals => {
        statistics: statistics
      }
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
      # 404 if article not found
      article_not_found if article.nil?
      erb :'board/article/index', :layout => :'board/layout', :locals => {
        article: article,
        back_url: (back.end_with?(to("/board/article/#{article['slug']}/edit"))) ? '/board/articles' : back
      }
    end

    get '/board/article/:slug/edit' do |slug|
      require_user
      # Get article record
      article = db.get_article_draft_or_published_by_slug(slug: slug)
      # 404 if article not found
      article_not_found if article.nil?
      erb :'board/article/edit', :layout => :'board/layout', :locals => {
        article: article,
        previous_article: session["article_edit:#{slug}"],
        back_url: (back == to("/board/article/#{article['slug']}/edit")) ? "/board/article/#{article['slug']}" : back
      }
    end

    get '/board/article/:slug/clear_edits' do |slug|
      require_user
      # Clear previous edits of article from session
      session["article_edit:#{slug}"] = nil
      redirect "/board/article/#{slug}/edit"
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

    get '/board/article/:slug/delete' do |slug|
      require_secret
      require_user
      # Delete article from database
      db.delete_article_by_slug(slug: slug)
      # New flash message
      new_flash 'success', 'article deleted'
      # Redirect
      redirect '/board/articles'
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
        previous_article: session["article_add"]
      }
    end

    get '/board/articles/clear_previous' do
      require_user
      # Clear previous article from session
      session['article_add'] = nil
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
      unless slug.empty? || title.empty? || abstract.empty? || content.empty?
        # Reset temporary article add storage
        session['article_add'] = nil
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
      session["article_add"] = {
        slug: slug, title: title, abstract: abstract, content: content,
        draft: draft
      }
      # Redirect
      redirect '/board/articles/add'
    end

    post '/board/article/:aslug/update' do |aslug|
      require_secret
      require_user
      # Get body data
      slug = params[:slug]
      title = params[:title]
      abstract = params[:abstract]
      content = params[:content]
      draft = (params[:draft] == 'on')
      # Check data
      unless slug.empty? || title.empty? || abstract.empty? || content.empty?
        # Reset temporary article edit storage
        session["article_edit:#{slug}"] = nil
        # Update article in database
        db.update_article(
          old_slug: aslug, author: session[:user_id], slug: slug, title: title,
          abstract: abstract, content: content, draft: draft
        )
        # New flash message
        new_flash 'success', 'article update'
        # Redirect
        redirect "/board/article/#{slug}"
        return
      end
      # New error flash
      new_flash 'error', 'wrong article details'
      # Store old article details in session
      session["article_edit:#{aslug}"] = {
        slug: slug, title: title, abstract: abstract, content: content,
        draft: draft
      }
      # Redirect
      redirect "/board/article/#{aslug}/edit"
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

    def article_not_found
      if @auth
        new_flash 'error', 'article does not exist'
        redirect '/board/articles'
      else
        erb :'error/article_not_found'
      end
    end

    error 404 do
      if @auth
        erb :'error/404', :layout => :'board/layout'
      else
        erb :'error/404'
      end
    end
  end
end
