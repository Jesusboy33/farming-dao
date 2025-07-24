import React, { useEffect, useState } from 'react';
import { callReadOnlyFunction } from '@stacks/transactions';
import { StacksTestnet } from '@stacks/network';

const CONTRACT_ADDRESS = 'ST000000000000000000002AMW42H'; // placeholder/fake
const CONTRACT_NAME = 'farming-dao';

function ProposalList() {
  const [proposals, setProposals] = useState([]);
  useEffect(() => {
    const fetchProposals = async () => {
      let result = [];
      for (let i = 0; i < 100; i++) {
        try {
          const response = await callReadOnlyFunction({
            contractAddress: CONTRACT_ADDRESS,
            contractName: CONTRACT_NAME,
            functionName: 'get-proposal',
            functionArgs: [{ type: 'uint', value: i }],
            senderAddress: CONTRACT_ADDRESS,
            network: new StacksTestnet(),
          });

          if (response && response.value) {
            result.push({ id: i, ...response.value });
          } else {
            break;
          }
        } catch (err) {
          break; // Stop at first error or undefined
        }
      }
      setProposals(result);
    };

    fetchProposals();
  }, []);

  return (
    <div>
      <h3> Proposals</h3>
      {proposals.length === 0 ? (
        <p>No proposals found.</p>
      ) : (
        <ul>
          {proposals.map((p) => (
            <li key={p.id}>
              <strong>#{p.id}</strong>: {p.description?.value || 'N/A'} | 
               {p.amount?.value} ustx | 
               {p['votes-for']?.value} /  {p['votes-against']?.value}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

export default ProposalList;
