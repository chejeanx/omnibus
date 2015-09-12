express = require 'express'
_ = require 'underscore'
fs = require 'fs'

config = JSON.parse fs.readFileSync './config.json'

questions = [
	'Hours worked'
	'Quality of work'
	'Creative contributions'
	'Easy to work with'
	'Availability'
	'Efficiency'
	'Leadership'
]

round = config.round

team_start = config.team_counter_start

users = {}
teams = []
names = {}
placeholder = '--Please Select--'

app = express()
passport = require 'passport'
session = require 'express-session'
flash = require 'connect-flash'
LocalStrategy = require('passport-local').Strategy
morgan = require 'morgan'
cookieParser = require 'cookie-parser'
bodyParser = require 'body-parser'

app.use morgan 'dev'
app.use cookieParser()
app.use bodyParser.json()
app.use bodyParser.urlencoded()

app.set 'views', './templates'
app.set 'view engine', 'jade'

app.engine 'jade', require('jade').__express

app.use session secret: 'omelette du frumage'
app.use passport.initialize()
app.use passport.session()
app.use flash()

passport.serializeUser (user, done) ->
	done null, user

passport.deserializeUser (id, done) ->
	done null, id

auth_data =
	usernameField: 'andrew_id'
	passwordField: 'survey_key'

auth_fn = (username, passwd, done) ->
	if (_(users).has username)# and (users[username] is passwd)
		return done null, {username}
	else
		return done null, false, message: 'Andrew ID not found'

passport.use 'local', new LocalStrategy auth_data, auth_fn

app.get '/', (req, res) ->
	res.render 'index', 
		flash: req.flash 'error'
		round: round

app.get '/stats', (req, res) ->
	total = _(users).values().length
	completed = _(users).keys().filter (m) ->
		fs.existsSync "./r#{round}_responses/#{m}.json"
	completed = _(completed).map (m) -> names[m]
	nclist = _(_(names).values()).difference completed
	res.render 'stats',
		round: round
		completed: completed.length
		not_completed: total - completed.length
		list: nclist


app.post '/login', passport.authenticate 'local',
	successRedirect: '/survey'
	failureRedirect: '/'
	failureFlash: true

app.get '/survey', (req, res) ->
	if !req.user
		req.flash 'error', 'Please log in with your survey key'
		res.redirect '/'
	else if fs.existsSync "./r#{round}_responses/#{req.user.username}.json"
		req.flash 'error', 'Your response for this round was already recorded. Please contact SUPPORT if you would like to edit your response.'
		req.logout()
		res.redirect '/'
	else	
		team = []
		for t in teams
			for m in t
				if m.toLowerCase().trim() is names[req.user.username].toLowerCase().trim()
					team = t
					continue
		team_no = _(teams).indexOf team
		team_no++
		team = _(team).compact()
		team.splice 0, 0, placeholder
		res.render 'survey',
			round: round
			team_no: team_no + team_start
			id: req.user.username
			name: names[req.user.username]
			questions: questions
			team: _(team).without names[req.user.username]

app.post '/survey', (req, res) ->
	resp = req.body
	react = {}
	if JSON.stringify(resp).indexOf(placeholder) > -1
		react =
			title: 'Incomplete'
			desc: 'Your submission was incomplete. Please answer all questions fully. Go back to try again.'
			go_back: true
	else
		vals = _(resp).values()
		test = _(vals).some (r) ->
			r.length > _(r).uniq().length
		if test
			react =
				title: 'Duplicate'
				desc: 'Your submission contained incorrect entries. Some question had the same person at two different ratings. Go back to try again.'
				go_back: true
		else
			filename = "./r#{round}_responses/#{req.user.username}.json"
			fs.writeFileSync filename, JSON.stringify resp
			react =
				title: 'Success!'
				desc: 'Your submission was recorded.'
				go_back: false
	res.render 'result', react
    
require('./parser') round, (data) ->
	users = data.users
	teams = data.teams
	names = data.names
	server = app.listen config.port, () ->
		console.log "listening on #{server.address().port}"
		dir = "./r#{round}_responses"
		if !fs.existsSync dir
			fs.mkdir "./r#{round}_responses"