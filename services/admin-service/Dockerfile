FROM ballerina/ballerina:2201.8.0

WORKDIR /app

COPY . .

RUN bal build

EXPOSE 9006

CMD ["bal", "run", "service.bal"]
