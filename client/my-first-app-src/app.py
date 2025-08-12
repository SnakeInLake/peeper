from flask import Flask, Response
import time
import random

# Создаем экземпляр нашего веб-приложения
app = Flask(__name__)

# Эта строка @app.route('/metrics') говорит:
# "Когда кто-то обратится к адресу /metrics, выполни функцию, которая идет следом"
@app.route('/metrics')
def generate_metrics():
    # Создадим два примера метрик для наглядности
    
    # 1. Метрика типа "счетчик" (Counter) - она всегда только растет.
    # Мы будем использовать текущее время в секундах.
    metric_counter_value = int(time.time())

    # 2. Метрика типа "измеритель" (Gauge) - она может расти и падать.
    # Мы будем использовать случайное число от 0 до 100.
    metric_gauge_value = random.randint(0, 100)

    # --- Формирование ответа в формате Prometheus ---
    # Это просто текст. Каждая метрика - на новой строке.
    # Формат: имя_метрики{метка1="значение1",метка2="значение2"} значение
    
    # Добавляем # HELP и # TYPE для соответствия стандарту. Это хорошая практика.
    data = "# HELP student_counter_total A counter that always goes up.\n"
    data += "# TYPE student_counter_total counter\n"
    # Добавляем саму метрику. В метках мы указываем, с какого хоста и из какого приложения она пришла.
    data += f'student_counter_total{{host="client",app="my-first-app"}} {metric_counter_value}\n'
    
    data += "\n" # Пустая строка для разделения метрик

    data += "# HELP student_gauge_random A gauge with a random value.\n"
    data += "# TYPE student_gauge_random gauge\n"
    data += f'student_gauge_random{{host="client",app="my-first-app"}} {metric_gauge_value}\n'
    
    # Возвращаем эти данные как простой текст
    return Response(data, mimetype='text/plain')

# Эта часть кода запускает веб-сервер, когда мы выполняем "python3 app.py"
if __name__ == '__main__':
    # Запускаем простое веб-приложение на порту 8080, доступное для всех внутри Docker
    app.run(host='0.0.0.0', port=9191)
