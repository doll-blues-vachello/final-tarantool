from locust import HttpUser, task, Locust
import random
import string
import requests
import argparse
import os



created_urls = []


def random_url():
    s = ''.join(random.choice(string.ascii_uppercase + string.digits) for _ in range(20))
    return f'https://example.com/{s}'


def create_urls(n: int):
    global created_urls
    s = requests.session()
    for _ in range(n):
        orig = random_url()
        short = s.post(f'{args.host}{args.endpoint}', data={args.param: orig}).text
        created_urls.append((short, orig))


class ShortenerUser(HttpUser):
    @task
    def shorten(self):
        with self.client.post(args.endpoint, data={args.param: random_url()}, catch_response=True) as response:
            if response.status_code != 200:
                response.failure(f"Error code received: {response.status_code}")

class CheckerUser(HttpUser):
    @task
    def shorten(self):
        short, orig = random.choice(created_urls)
        with self.client.get(short, catch_response=True, allow_redirects=False) as response:
            # print(response.headers.get('Location'), orig)
            if response.headers.get('Location') != orig:
                response.failure(f"Error code received: {response.status_code}")

args = {}


def print_test(stats):
    print(f'Rps = {stats["num_requests"]/(stats["end_time"] - stats["start_time"])}')

if __name__ == '__main__':
    import invokust

    parser = argparse.ArgumentParser()
    parser.add_argument('--host', type=str, default='http://tarantool.leadpogrommer.ru:80', help='http://host:port')
    parser.add_argument('--param', type=str, default='url', help='Post parameter name for setting link')
    parser.add_argument('--endpoint', type=str, default='/api/set', help='Url shorten endpoint')
    parser.add_argument('--create_duration', type=int, default=30, help='How long to test link creation')
    parser.add_argument('--redirect_duration', type=int, default=60, help='How long to test link usage')

    args = parser.parse_args()


    settings = invokust.create_settings(
        classes=[ShortenerUser],
        host=args.host,
        num_users=100,
        spawn_rate=50,
        run_time=f'{args.create_duration}s',
        loglevel='ERROR'
    )

    loadtest = invokust.LocustLoadTest(settings)
    loadtest.run()
    create_url_stats = loadtest.stats()


    print('Creating and remembering 100 urls')
    create_urls(100)
    print('Created urls')

    settings = invokust.create_settings(
        classes=[CheckerUser],
        host=args.host,
        num_users=1000,
        spawn_rate=50,
        run_time=f'{args.redirect_duration}s',
        loglevel='ERROR'
    )

    loadtest = invokust.LocustLoadTest(settings)
    loadtest.run()
    redirect_stats = loadtest.stats()
    os.system('clear')
    print("Create url:")
    print_test(create_url_stats)
    print("Use url:")
    print_test(redirect_stats)

