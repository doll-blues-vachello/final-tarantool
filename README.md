# Tarantool task
Running at http://tarantool.leadpogrommer.ru/
### shorten url
POST http://tarantool.leadpogrommer.ru/api/set
post parameter `url` - url to shorten
### Testing
`pip3 install --user locust invokust`
`python3 load_testing/locustfile.py --help`