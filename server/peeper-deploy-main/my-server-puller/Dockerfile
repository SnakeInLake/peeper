FROM python:3.9-slim
WORKDIR /app
RUN pip install Flask==2.2.2 "Werkzeug<3.0.0"
COPY . .
CMD ["python3", "-u", "app.py"]
