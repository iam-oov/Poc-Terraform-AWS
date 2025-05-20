FROM node:24-slim

WORKDIR /usr/src/app

COPY app/package*.json ./

RUN yarn install --production

COPY app/ ./

EXPOSE 3011

ENV NODE_ENV=development

CMD ["yarn", "start"]
