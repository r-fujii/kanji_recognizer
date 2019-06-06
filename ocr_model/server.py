from predict import save_dec_image, load_model, get_cls
from flask import Flask, request, jsonify
import os
import json

# settings for ocrmodel
with open('./params.json') as f:
    params = json.load(f)

idx2cls = params['idx2cls']
model = load_model('./kanji_recognizer_best.pt', idx2cls)

app = Flask(__name__)

@app.route('/')
def index():
    return 'hello'


@app.route('/post', methods=['POST'])
def post():
    base64image = request.form['data']
    save_dec_image(encoded_image=base64image)
    pred_clses = get_cls(model, idx2cls, 6)

    return jsonify({rank: {'cls': cls, 'score': score} for rank, (cls, score) in enumerate(pred_clses)})


if __name__ == '__main__':
    port = int(os.getenv('PORT', 2036))
    app.run(host='0.0.0.0', port=port, debug=True)
