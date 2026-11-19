// os 11 quartéis do RSB (posição de saída dos VUCI, a mesma de QUARTEIS_GPS no quarteis-112)
window.QUARTEIS = [
  ["Dom Carlos", 38.709966421832064, -9.153511838833419], ["Martim Moniz", 38.714893, -9.136737], ["Graça", 38.71703284226991, -9.129548312251869],
  ["Defensores de Chaves", 38.732815, -9.142205], ["Santo Amaro", 38.703316, -9.184975], ["Monsanto", 38.72648, -9.197547],
  ["Benfica", 38.750084, -9.196485], ["Alvalade", 38.756626, -9.140233], ["Encarnação", 38.77001, -9.123547],
  ["Alta de Lisboa", 38.77936, -9.143878], ["Marvila", 38.752216, -9.104897]
].map(([nome, lat, lng]) => ({ nome, lat, lng }));
