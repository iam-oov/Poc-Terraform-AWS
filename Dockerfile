# We use the official Node.js 24 image with a slim version
FROM node:24-slim

# We set the working directory to /usr/src/app
WORKDIR /usr/src/app

# We copy the package.json file from the app directory
COPY app/package*.json ./

# We install the dependencies with yarn in production mode
RUN yarn install --production

# We copy the rest of the app files
COPY app/ ./

# We expose the port 3011
EXPOSE 3011

# We set the NODE_ENV environment variable to development
ENV NODE_ENV=development

# We set the default command to start the app with yarn
CMD ["yarn", "start"]
