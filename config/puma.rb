max_threads_count = ENV.fetch('SINATRA_MAX_THREADS') { 5 }
min_threads_count = ENV.fetch('SINATRA_MIN_THREADS') { max_threads_count }
threads min_threads_count, max_threads_count
worker_timeout 3600 if ENV.fetch('RACK_ENV', 'development') == 'development'
port ENV.fetch('PORT') { 5000 }
environment ENV.fetch('RACK_ENV') { 'development' }
workers ENV.fetch('WEB_CONCURRENCY') { 2 }
