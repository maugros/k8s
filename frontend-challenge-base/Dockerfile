FROM node:20.14.0
WORKDIR /app
COPY ./package*.json ./
COPY . .
RUN npm install 
RUN npx next telemetry disable
WORKDIR /app/src
EXPOSE 3000
CMD ["npm", "run", "dev"]