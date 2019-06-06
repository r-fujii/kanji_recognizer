from __future__ import print_function
import argparse
import torch
import torch.nn as nn
import torch.nn.functional as F
import torch.optim as optim
from torchvision import datasets, transforms
from sklearn.model_selection import train_test_split

import sys
import json
import time
from logzero import logger


class Net(nn.Module):
    def __init__(self, num_chars):
        super(Net, self).__init__()
        self.conv1 = nn.Conv2d(3, 20, 5)
        self.conv2 = nn.Conv2d(20, 50, 5)
        self.fc1 = nn.Linear(50 * 4 * 4, 500)
        self.fc2 = nn.Linear(500, num_chars)

    def forward(self, x):
        x = F.relu(self.conv1(x)) # 3 channels -> 20 channels with 20 (5 * 5)-sized filters (3 * 28 * 28 -> 20 * 24 * 24)
        x = F.max_pool2d(x, 2) # take maximum value of adjacent 2 * 2 elements (20 * 12 * 12)
        x = F.relu(self.conv2(x)) # 20 -> 50 channels with 50 (5 * 5)-sized filters (20 * 12 * 12 -> 50 * 8 * 8)
        x = F.max_pool2d(x, 2) # (50 * 4 * 4)
        x = x.view(-1, 50 * 4 * 4) # automatically flatten tensors to given size (when first arg == -1)
        x = F.relu(self.fc1(x))
        x = self.fc2(x)
        return F.log_softmax(x, dim=1)


def train(args, model, device, train_loader, optimizer, epoch):
    model.train()
    for batch_idx, (data, target) in enumerate(train_loader):
        data, target = data.to(device), target.to(device)
        optimizer.zero_grad()
        output = model(data)
        loss = F.nll_loss(output, target)
        loss.backward()
        optimizer.step()
        if batch_idx % args.log_interval == 0:
            print('Train Epoch: {} [{}/{} ({:.0f}%)]\tLoss: {:.6f}'.format(
                epoch, batch_idx * len(data), len(train_loader.dataset),
                       100. * batch_idx / len(train_loader), loss.item()))


def test(args, model, device, test_loader):
    model.eval()
    dev_loss = 0
    correct = 0
    with torch.no_grad():
        for data, target in test_loader:
            data, target = data.to(device), target.to(device)
            output = model(data)
            dev_loss += F.nll_loss(output, target, reduction='sum').item()  # sum up batch loss
            pred = output.argmax(dim=1, keepdim=True)  # get the index of the max log-probability
            correct += pred.eq(target.view_as(pred)).sum().item()

    dev_loss /= len(test_loader.dataset)

    print('\nDev set: Average loss: {:.4f}, Accuracy: {}/{} ({:.0f}%)\n'.format(
        dev_loss, correct, len(test_loader.dataset),
        100. * correct / len(test_loader.dataset)))

    return dev_loss


def predict(model, device, pred_loader, nbest):
    model.eval()
    with torch.no_grad():
        for data, _ in pred_loader:
            # assert data (in a batch) to be single input
            assert len(data) == 1
            data = data.to(device)
            output = model(data)
            rank = torch.argsort(output, dim=1, descending=True)[0][:nbest]
            pred_idxs = [(idx.item(), output[0][idx].item()) for idx in rank]

        return pred_idxs


def read_dataset(root_dir, seed, transform=None):
    dataset = datasets.ImageFolder(root=root_dir, transform=transform)
    idx2cls = {idx: cls for cls, idx in dataset.class_to_idx.items()}
    # set the ratio of test size to whole corpus size smaller (corpus size is over 2 million)
    train_data, dev_data = train_test_split(dataset, test_size=0.01, random_state=seed)
    return train_data, dev_data, idx2cls


def main():
    # Training settings
    parser = argparse.ArgumentParser(description='A modified version of Pytorch MNIST example to classify kanji characters')
    parser.add_argument('--batch-size', type=int, default=64, metavar='N',
                        help='input batch size for training (default: 64)')
    parser.add_argument('--test-batch-size', type=int, default=1000, metavar='N',
                        help='input batch size for testing (default: 1000)')
    parser.add_argument('--epochs', type=int, default=20, metavar='N',
                        help='number of epochs to train (default: 10)')
    parser.add_argument('--lr', type=float, default=0.01, metavar='LR',
                        help='learning rate (default: 0.01)')
    parser.add_argument('--momentum', type=float, default=0.5, metavar='M',
                        help='SGD momentum (default: 0.5)')
    parser.add_argument('--no-cuda', action='store_true', default=False,
                        help='disables CUDA training')
    parser.add_argument('--seed', type=int, default=1, metavar='S',
                        help='random seed (default: 1)')
    parser.add_argument('--log-interval', type=int, default=100, metavar='N',
                        help='how many batches to wait before logging training status')

    parser.add_argument('--save-model-each-epoch', action='store_true', default=False,
                        help='Save the model each epoch')
    parser.add_argument('--root-dir', type=str, default='.',
                        help='path for dataset where data is stored in structured manner')
    args = parser.parse_args()

    use_cuda = not args.no_cuda and torch.cuda.is_available()

    torch.manual_seed(args.seed)

    device = torch.device('cuda' if use_cuda else 'cpu')

    # kwargs = {'num_workers': 1, 'pin_memory': True} if use_cuda else {}
    logger.info('loading dataset...')
    # perhaps some normalization is necessary...
    train_data, dev_data, idx2cls = read_dataset(args.root_dir, seed=args.seed, transform=transforms.ToTensor())

    train_loader = torch.utils.data.DataLoader(train_data, batch_size=args.batch_size, shuffle=True)
    dev_loader = torch.utils.data.DataLoader(dev_data, batch_size=args.test_batch_size, shuffle=False)
    logger.info('dataset preparation completed')

    params = args.__dict__
    params['idx2cls'] = idx2cls
    # save parameters
    with open('./params.json', 'w') as f:
        json.dump(params, f)

    model = Net(len(idx2cls)).to(device)
    optimizer = optim.SGD(model.parameters(), lr=args.lr, momentum=args.momentum)
    min_test_loss = sys.float_info.max

    train_start_time = time.time()
    for epoch in range(1, args.epochs + 1):
        train(args, model, device, train_loader, optimizer, epoch)
        dev_loss = test(args, model, device, dev_loader)

        if args.save_model_each_epoch:
            torch.save(model.state_dict(), 'kanji_recognizer_ep{}.pt'.format(epoch))
            logger.info('saved checkpoint: ep{}'.format(epoch))
        if dev_loss < min_test_loss:
            torch.save(model.state_dict(), 'kanji_recognizer_best.pt')
            logger.info('best model now updated')
            min_test_loss = dev_loss

    torch.save(model.state_dict(), 'kanji_recognizer_last.pt')
    elapsed_time = time.time() - train_start_time
    logger.info('training finished in {} seconds'.format(round(elapsed_time)))


if __name__ == '__main__':
    main()
