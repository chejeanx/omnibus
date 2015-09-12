fs = require 'fs'
parse = require 'csv-parse'

module.exports = (round, cb) ->
	input = fs.readFileSync './in.csv'
	round = fs.readFileSync "r#{round}.csv"
	out = {
		users: {}
		teams: []
		names: {}
	}
	parse input, {}, (err, data) ->
		if err
			abort err
		else
			for d in data
				out['users'][d[1].split('@')[0]] = d[2]
				out['names'][d[1].split('@')[0]] = d[0]
			parse round, {}, (err, data) ->
				if err
					abort err
				else
					out.teams = data
					cb out