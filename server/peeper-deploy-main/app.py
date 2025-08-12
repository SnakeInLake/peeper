from flask import Flask, Response
import os

app = Flask(__name__)

@app.route('/metrics')
def generate_server_metrics():
    try:
        # Читаем файл /proc/uptime. В нем два числа, нам нужно первое.
        # Мы открываем его через /host/proc/uptime, так как вся система хоста
        # будет смонтирована в /host.
        with open('/host/proc/uptime', 'r') as f:
            uptime_seconds = float(f.readline().split()[0])
        
        data = "# HELP server_uptime_seconds The uptime of the server.\n"
        data += "# TYPE server_uptime_seconds gauge\n"
        data += f'server_uptime_seconds{{host="server"}} {uptime_seconds}\n'

    except Exception as e:
        # Если что-то пошло не так, вернем ошибку
        data = f'# Error reading metrics: {e}\n'
        
    return Response(data, mimetype='text/plain')


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=9393) # Будем использовать новый порт 9393
