from flask import Flask, request, jsonify, render_template
from flask_sqlalchemy import SQLAlchemy
import datetime
import os

# Initialize the app and database
app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'mysql+pymysql://username:password@localhost/StarCitizenIntel'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SECRET_KEY'] = os.urandom(24)

# Discord OAuth2 Configuration
DISCORD_CLIENT_ID = '1203001919707156491'
DISCORD_CLIENT_SECRET = 'rSLUWTwNfFOeDKBNe8S06Ek7WM2HjiXX'
DISCORD_REDIRECT_URI = 'https://discord.com/oauth2/authorize?client_id=1203001919707156491&response_type=code&redirect_uri=http%3A%2F%2Flocalhost%3A5000%2Fcallback&scope=identify'

# Initialize database
db = SQLAlchemy(app)

# Database models
class Player(db.Model):
    __tablename__ = 'players'
    player_id = db.Column(db.Integer, primary_key=True)
    player_name = db.Column(db.String(255), nullable=False)
    alternate_names = db.Column(db.Text)

class Incident(db.Model):
    __tablename__ = 'incidents'
    incident_id = db.Column(db.Integer, primary_key=True)
    player_id = db.Column(db.Integer, db.ForeignKey('players.player_id'))
    location = db.Column(db.String(255), nullable=False)
    type_of_incident = db.Column(db.String(100))
    subcategory = db.Column(db.String(100))
    description = db.Column(db.Text)
    incident_time = db.Column(db.DateTime, nullable=False)
    timestamp = db.Column(db.DateTime, default=datetime.datetime.utcnow)

class Ship(db.Model):
    __tablename__ = 'ships'
    ship_id = db.Column(db.Integer, primary_key=True)
    incident_id = db.Column(db.Integer, db.ForeignKey('incidents.incident_id'))
    ship_name = db.Column(db.String(255), nullable=False)

# Routes
@app.route('/api/report', methods=['POST'])
def report_incident():
    data = request.json

    # Check for existing player or create new
    player = Player.query.filter_by(player_name=data['player_name']).first()
    if not player:
        player = Player(player_name=data['player_name'], alternate_names=data.get('alternate_names'))
        db.session.add(player)
        db.session.commit()

    # Create incident
    incident = Incident(
        player_id=player.player_id,
        location=data['location'],
        type_of_incident=data['type_of_incident'],
        subcategory=data['subcategory'],
        description=data['description'],
        incident_time=datetime.datetime.strptime(data['incident_time'], '%Y-%m-%d %H:%M:%S')
    )
    db.session.add(incident)
    db.session.commit()

    # Add ships
    for ship_name in data.get('ships', []):
        ship = Ship(incident_id=incident.incident_id, ship_name=ship_name)
        db.session.add(ship)
    db.session.commit()

    return jsonify({"message": "Incident reported successfully."}), 201

@app.route('/api/query', methods=['GET'])
def query_incidents():
    player_name = request.args.get('player_name')
    location = request.args.get('location')
    type_of_incident = request.args.get('type_of_incident')
    subcategory = request.args.get('subcategory')

    query = Incident.query.join(Player).filter(
        (Player.player_name == player_name) if player_name else True,
        (Incident.location == location) if location else True,
        (Incident.type_of_incident == type_of_incident) if type_of_incident else True,
        (Incident.subcategory == subcategory) if subcategory else True
    )

    results = []
    for incident in query.all():
        ships = Ship.query.filter_by(incident_id=incident.incident_id).all()
        results.append({
            "incident_id": incident.incident_id,
            "player_name": incident.player.player_name,
            "location": incident.location,
            "type_of_incident": incident.type_of_incident,
            "subcategory": incident.subcategory,
            "description": incident.description,
            "incident_time": incident.incident_time,
            "timestamp": incident.timestamp,
            "ships": [ship.ship_name for ship in ships]
        })

    return jsonify(results), 200

@app.route('/api/report_summary', methods=['GET'])
def report_summary():
    summary = db.session.query(
        Incident.type_of_incident, Incident.subcategory, db.func.count(Incident.incident_id)
    ).group_by(Incident.type_of_incident, Incident.subcategory).all()

    summary_report = {"summary": [
        {"type_of_incident": row[0], "subcategory": row[1], "count": row[2]} for row in summary
    ]}

    return jsonify(summary_report), 200

@app.route('/intel')
def index():
    return render_template('index.html')

if __name__ == '__main__':
    db.create_all()  # Ensure tables are created
    app.run(debug=True)
