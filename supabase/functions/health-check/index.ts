export async function healthCheck() {
  return {
    status: 'ok',
    timestamp: new Date().toISOString(),
    message: 'API is healthy'
  };
}