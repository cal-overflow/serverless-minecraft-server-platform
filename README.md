# Serverless Minecraft Server Platform

This repository is an archive of an abandoned project. The project is a platform that would allow users to have their very own serverless Minecraft  server built with a variety of AWS resources (most notably ECS). The platform is scalable such that other games could be implemented. \
Learn more about the project and its complexities [here](https://cal-overflow.dev/post/serverless-minecraft-servers).

#### Project structure
There are three Cloudformation stacks included. The Hierarchy is as follows:
- [smarter-servers.net](./smarter-servers.net.template.yml)
  - [mc.smarter-servers.net](./mc.smarter-servers.net.template.yml)
    - [Individual Minecraft Server](./template.yml)

Also included is the source code for the [ECS watchdog](./watchdog) task as well as the [Lambda function that starts the ECS tasks](./power-on-mc-server-lambda-fn).

## Looking for ways to save money on your Minecraft Server?
Check out these alternative solutions:
- [ec2-serverless-minecraft-server](https://github.com/cal-overflow/ec2-serverless-minecraft-server) - Simple setup + GitHub integration
- [minecraft-ondemand](https://github.com/doctorray117/minecraft-ondemand) - Complex setup but more advanced
