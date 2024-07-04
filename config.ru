# frozen_string_literal: true

require 'roda'

class App < Roda
	# Roda usually extracts HTML to separate files, but we'll inline it here.
	BODY = <<~HTML
		<!DOCTYPE html>
		<html lang="en">
		<head>
			<meta charset="UTF-8">
			<title>WebSockets Example</title>
		</head>
		<body>
		  <script src="https://unpkg.com/htmx.org@2.0.0"></script>
		  <script src="https://unpkg.com/htmx.org@1.9.12/dist/ext/ws.js"></script>

			<div hx-ext="ws" ws-connect="/chatroom">
				<form id="form" ws-send>
						<input id="pineapples" type="number" name="pineapples" value="5" />
						<button>Send</button>
				</form>

				<div id="chat_room" style="margin-top: 1rem;">
				</div>
			</div>
		</body>
		</html>
	HTML

	plugin :websockets
	plugin :common_logger

  def message(value)
    msg = <<~HTML
			<!-- will be swapped using an extension -->
			<div id="chat_room" hx-swap-oob="morphdom">
					#{value}
			</div>
		HTML

		msg
  end

	def on_message(connection, message)
	  json = JSON.parse(message.buffer)
		pineapples = json['pineapples']&.to_i

		Async do |task|
			connection.write "Eating #{pineapples} pineapples."
			connection.flush

			pineapples.downto(1) do |n|
				task.sleep 1
				connection.write message('🍍' * n)
				connection.flush
			end
			task.sleep 1

			connection.write message("Ate #{pineapples} pineapples.")
			connection.flush
		end

	rescue e
		connection.write "Error: #{e.message}"
	end

	def messages(connection)
		Enumerator.new do |yielder|
			loop do
				message = connection.read
				break unless message

				yielder << message
			end
		end
	end

	route do |r|
		r.is 'chatroom' do
			r.websocket do |connection|
				messages(connection).each do |message|
					on_message(connection, message)
				end
			end
		end
		r.is '' do
			r.get do
				BODY
			end
		end
	end
end

run App.freeze.app
