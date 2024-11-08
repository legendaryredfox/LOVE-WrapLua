![Greetings](images/warudo.png)

# Disclaimers

- Shoutout to the [OneLua](http://onelua.x10.mx/) team, for their contributions for the development community for these amazing plaforms
- I focus on the PSP platform. It should work just fine with any other of the platforms originally intended, but you may have to fiddle with the code, specially the `filesystem.lua` file
- I'm currently using Lua 5.4 and LÖVE 11.5 (Mysterious Mysteries)
- This project was NOT developed with clean code/best practices in mind. If it works, it works.
- Original project by [LukeZGD](https://github.com/LukeZGD/LOVE-WrapLua). This project appears to be archived, so I'm trying to implement features that may be useful for me or other people
- I'm not an experienced lua programmer, keep that in mind when using this code
- Feel free to open issues with features you'd like to see implemented. Just please, for all that is good and sacred, write a thorough description.
- Stuff from the original project that do not fit the PSP environment may have been commented out, but kept in place
- This is a hobby project, stuff will get upgraded whenever I have the time to go over them
- Most of this code has not been fully tested
- Most of the testing is carried out using RetroArch
- Assets used in the sample project are from [Kenney](https://kenney.nl/assets/scribble-dungeons) and [game-endeavor](https://game-endeavor.itch.io/mystic-woods), go show them some love if you can!

# LOVE-WrapLua

A small and simple LOVE2D wrapper for OneLua, lpp-vita, and Lua Player PS3

You can use this to make LOVE2D stuff for a PSP, PS Vita, and/or PS3! As an example, this is used on [DDLC-LOVE](https://github.com/LukeZGD/DDLC-LOVE/)

This is made just for fun and will only have the basic stuff.

- See `Implemented.md` for the list of implemented stuff
- `script.lua` is the main file for LOVE-WrapLua (required)
- `index.lua` is for lpp-vita to run `script.lua` (required for lpp-vita only)
- `app.lua` is for Lua Player PS3 to run `script.lua` (required for Lua Player PS3 only)
- `lv1luaconf` in `conf.lua` is to set up some settings for key configuration `keyconf`, resolution scale `resscale`, and image scale `imgscale`. This is optional; See `script.lua` for the default values
