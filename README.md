# Apollon
Shell script to install an [Apollon Masternode](http://apolloncoin.io/) on a Linux server running Ubuntu 16.04. Use it on your own risk.  
***

## Installation for version 1.0.6
```
wget -q https://raw.githubusercontent.com/zoldur/Apollon/master/apollon_install.sh
bash apollon_install.sh
```
***

## Desktop wallet setup  

After the MN is up and running, you need to configure the desktop wallet accordingly. Here are the steps:  
1. Open the Apollon Desktop Wallet.  
2. Go to RECEIVE and create a New Address: **MN1**  
3. Send **25000** XAP to **MN1**.  
4. Wait for 16 confirmations.  
5. Go to **Help -> "Debug Window - Console"**  
6. Type the following command: **masternode outputs**  
7. Go to **Masternodes** tab  
8. Click **Create** and fill the details:  
* Alias: **MN1**  
* Address: **VPS_IP:PORT**  
* Privkey: **Masternode Private Key**  
* TxHash: **First value from Step 6**  
* Output index:  **Second value from Step 6**  
* Reward address: leave blank  
* Reward %: leave blank  
9. Click **OK** to add the masternode  
10. Click **Start All**  
***

## Usage:
```
Apollond masternode status  
Apollond getinfo
```
Also, if you want to check/start/stop **Apollon**, run one of the following commands as **root**:

```
systemctl status Apollon #To check if Apollon service is running  
systemctl start Apollon #To start Apollon service  
systemctl stop Apollon #To stop Apollon service  
systemctl is-enabled Apollon #To check if Apollon service is enabled on boot  
```  
***

## Issues:
For some reasons when Apollon starts for the first time, it will not  update the blockchain. Try this to fix
```
Apollond getinfo
systemctl stop Apollon
rm -r /root/.Apollon/{blk0001.dat,mncache.dat,peers.dat,smsgDB,smsg.ini,txleveldb}
sleep 10
systemctl start Apollon
Apollond getinfo
```
***

## Masternode update:
In order to update your Masternode to version 1.0.6, please run the following commands:
```
cd /tmp
systemctl stop Apollon
rm Apollond.tar.gz >/dev/null 2>&1
wget -N https://github.com/apollondeveloper/ApollonCoin/releases/download/1.0.6/Apollond.tar.gz
tar xvzf Apollond.tar.gz
chmod +x Apollond
cp Apollond /usr/local/bin
systemctl start Apollon
```
***

## Donations

Any donation is highly appreciated  

**XAP**: AMyyebyE8N5f79xLGtXRqLswjeHqbe2cBP  
**BTC**: 3MQLEcHXVvxpmwbB811qiC1c6g21ZKa7Jh  
**ETH**: 0x39d10fe57611c564abc255ffd7e984dc97e9bd6d  
**LTC**: LNZpK4rCd1JVSB3rGKTAnTkudV9So9zexB
