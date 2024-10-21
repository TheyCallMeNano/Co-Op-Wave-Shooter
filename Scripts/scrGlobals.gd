extends Node


var chatLog = []
var connectedIDs = []
var clientObj = []
var gravity = 9.8
var waveNum = 0
var waveNumMax = 0
var eAlive = 0
var eMax = 0
var objHP = 100
@export_enum("Easy", "Normal", "Hard") var difficulty : int
