from ocrmodel import Net, predict
import torch
from torch.utils.data import Dataset
from torchvision import transforms
from skimage import io

import json
import base64
from PIL import Image
import argparse


class TestImage(Dataset):
    # for testing (including only 1 instance)

    def __init__(self, img_path, transform=None):
        self.data = [(io.imread(img_path), -1)] # set label to -1 (not used)
        self.transform = transform

    def __len__(self):
        return len(self.data) # always 1

    def __getitem__(self, idx):
        image, label = self.data[idx]
        if self.transform:
            image = self.transform(image)

        return image, label


def save_dec_image(encoded_image):
    image = base64.b64decode(encoded_image)
    with open('./tmp/image.png', 'bw') as f:
        f.write(image)

    # delete alpha channel
    rgb_image = Image.open('./tmp/image.png').convert('RGB')
    rgb_image.save('./tmp/processed.png')


def load_model(model_path, idx2cls):
    model = Net(len(idx2cls))
    model.load_state_dict(torch.load(model_path, map_location='cpu'))

    return model


def get_cls(model, idx2cls, nbest=1):
    pred_loader = torch.utils.data.DataLoader(
        TestImage(img_path='./tmp/processed.png', transform=transforms.ToTensor()), batch_size=1)
    pred_idxs = predict(model, 'cpu', pred_loader, nbest)
    return [(idx2cls.get(str(pred_idx[0]), '-'), pred_idx[1]) for pred_idx in pred_idxs]


def main(args):
    with open(args.config) as f:
        params = json.load(f)

    idx2cls = params['idx2cls']

    model = load_model(args.model, idx2cls)
    # base64-encoded sample image
    save_dec_image(encoded_image="iVBORw0KGgoAAAANSUhEUgAAABwAAAAcCAYAAAByDd+UAAAAAXNSR0IArs4c6QAAABxpRE9UAAAAAgAAAAAAAAAOAAAAKAAAAA4AAAAOAAAA+L69UF4AAADESURBVEgNzJQ7C4QwEIT9\/79KTLAJ0SJgoQSNoI2PJiI+0DkMXHEIxiLnXWCqLPlmd9h4ePh4D\/NgBU7TZDxprZFl2UlKKez7ftu3FcgYwwEbhgFSypPiOEYYhu6AURShaZrLB4MgwLZtlzXvS2uHd4CEELfAtm2xLAvqukZVVR\/qug6UUvfAcRwhhDjpyNU50Jah85H+DLiuq1mPw0BZlsjz3GTrfKR936MoCvi+b3aOc44kSZCmKeZ5\/k6GV7\/JX2f4AgAA\/\/8fh6R\/AAABU0lEQVS9lGurgkAQhvv\/PymSyoyCRKXECoIuXxI1QaUbpu\/hXdiFE+Xq+XAGlll2ZufZnZ3ZHjTiOA7iOG70mkwmqOu60Ucae3LyTdu2jSiKlPnxeOByueBwOMD3fbiuC9M0lV030QLTNAUhx+MRo9EI4\/FYAIIgwOl0EmO3233lvN9cC5SRXq8X8jwH9WKxkMtazScpy1L5tQbyFsvlUgCn06kKoJvMZjNkWabcWgGZVsMwBIzp7QL0PA9hGLYH3m439Pt9FEUhNnUFbrdb7Pf7dsAkSQSMWgrfkIXTVlhY6\/VauX9M6f1+B9uBVclCeRfaGEgnLJbVatUM5GkGg8GvNLwHZlqHw6GoVqZLtgfn3M9342dAn\/l8Dl5Airrh8\/mEZVmikauqkvZGfT6fsdlswJ7k4HuxX7l+vV4\/7lVAnkL3hX2M0HFRATvu+7P7vwN\/AC+Q7\/BmagrwAAAAAElFTkSuQmCC")
    pred_clses = get_cls(model, idx2cls, 6)
    for cls, score in pred_clses:
        print('cls: {}, score: {}'.format(cls, score))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='A modified version of Pytorch MNIST example to classify kanji characters (for prediction)')
    parser.add_argument('--model', type=str, required=True,
                        help='path for model file')
    parser.add_argument('--config', type=str, required=True,
                        help='path for configuration (param) file')
    args = parser.parse_args()

    main(args)

