FROM godotimages/godot:3.4.2

WORKDIR /usr/src/app
COPY . .

ENTRYPOINT ["/usr/local/bin/godot", "project.godot"]
