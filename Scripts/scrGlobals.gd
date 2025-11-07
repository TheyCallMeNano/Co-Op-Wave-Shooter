extends Node


# This shit needs to go somewhere else I don't know what I was fucking thinking when I made this
# MultiplayerSynchronizer really doesn't like having a non secure node pointer
# Break these up to where they should be; enemy stuff in waveManager etc.
var chatLog := []
var clientObj := []
var gravity := 9.8
var waveNum := 0
var waveNumMax := 0
var eAlive := 0
var eMax := 0
var objHP := 100
@export_enum("Easy", "Normal", "Hard") var difficulty : int
