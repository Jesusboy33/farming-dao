import React, { useState } from 'react';
import { StacksTestnet } from '@stacks/network';
import { openContractCall, showConnect } from '@stacks/connect';
import { userSession } from './userSession';
import ProposalForm from './components/ProposalForm';

const CONTRACT_ADDRESS = 'YOUR_DEPLOYED_CONTRACT_ADDRESS'; // update after deployment
const CONTRACT_NAME = 'farming-dao';

function App() {
  const [userData, setUserData] = useState(userSession.isUserSignedIn() ? userSession.loadUserData() : null);

  const connectWallet = () => {
    showConnect({
      appDetails: {
        name: 'Farming DAO',
        icon: window.location.origin + '/logo.png',
      },
      userSession,
      onFinish: () => setUserData(userSession.loadUserData()),
    });
  };

  const callRegisterFarmer = async () => {
    await openContractCall({
      contractAddress: CONTRACT_ADDRESS,
      contractName: CONTRACT_NAME,
      functionName: 'register-farmer',
      functionArgs: [],
      network: new StacksTestnet(),
      appDetails: {
        name: 'Farming DAO',
        icon: window.location.origin + '/logo.png',
      },
    });
  };

  const callContribute = async () => {
    const amountUstx = prompt('Enter contribution amount in micro-STX (1 STX = 1_000_000 ustx):');
    const amount = parseInt(amountUstx);

    if (amount && amount >= 1000) {
      await openContractCall({
        contractAddress: CONTRACT_ADDRESS,
        contractName: CONTRACT_NAME,
        functionName: 'contribute',
        functionArgs: [uintCV(amount)],
        postConditionMode: 1,
        postConditions: [],
        network: new StacksTestnet(),
        appDetails: {
          name: 'Farming DAO',
          icon: window.location.origin + '/logo.png',
        },
      });
    } else {
      alert('Enter a valid amount (min 1000 ustx)');
    }
  };

  return (
    <div style={{ padding: 20 }}>
      <h1> Farming DAO</h1>

      {!userData ? (
        <button onClick={connectWallet}>Connect Wallet</button>
      ) : (
        <>
          <p>👤 Connected: {userData.profile.stxAddress.testnet}</p>

          <button onClick={callRegisterFarmer}>✅ Register as Farmer</button>
          <button onClick={callContribute}>💰 Contribute</button>

          <hr />

          <ProposalForm contractAddress={CONTRACT_ADDRESS} />
        </>
      )}
    </div>
  );
}

export default App;
