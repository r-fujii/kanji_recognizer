kanji_recognizer
====

## Description
手書き入力された常用漢字を読み取るiOSアプリです。  
モデルには学習データとして、Chinese Characters dataset(https://blog.usejournal.com/making-of-a-chinese-characters-dataset-92d4065cc7cc) に含まれる漢字のうち、2019年6月時点でWikipedia-常用漢字一覧(https://ja.wikipedia.org/wiki/常用漢字一覧) にあげられる2137字に対応した28×28サイズのPNG約2M枚を用いています。アーキテクチャは手書き数字認識のモデル(PyTorch MNIST example)をベースとし、分類クラス数を常用漢字に含まれる漢字数に対応させたものを用いています。データセットよりランダムにサンプリングした1%のdev setに対してロスが最小となったモデルを使用し、accuracyは94%程度です。入力された手書き画像に対して尤度の高い漢字6字を表示します。  
UIはSwift、モデルおよびjsonデータのやりとりを行うサーバ部分はPythonで記述されています。

## Demo

![Movie](https://github.com/r-fujii/kanji_recognizer/blob/media/kanji_recognizer_demo.gif)

## Author

[r-fujii](https://github.com/r-fujii)
