export function publisherRunIdFromDispatch(responseText, owner, repo) {
  if (typeof responseText !== 'string' || !responseText.trim()) throw new Error('GitHub workflow dispatch returned no run details; refusing to redispatch or guess the run.');
  let dispatch;
  try {
    dispatch = JSON.parse(responseText);
  } catch {
    throw new Error('GitHub workflow dispatch returned invalid JSON; refusing to redispatch or guess the run.');
  }
  const prefix = `https://api.github.com/repos/${owner}/${repo}/actions/runs/`;
  if (!Number.isSafeInteger(dispatch?.workflow_run_id) || dispatch.workflow_run_id <= 0 || dispatch.run_url !== `${prefix}${dispatch.workflow_run_id}`) {
    throw new Error('GitHub workflow dispatch response lacks an exact repository-bound run ID; refusing to redispatch.');
  }
  return dispatch.workflow_run_id;
}

export function verifyPublisherJobs(jobsResponse, runId, runAttempt, isDryRun) {
  if (!jobsResponse || !Array.isArray(jobsResponse.jobs) || !Number.isInteger(jobsResponse.total_count) || jobsResponse.jobs.length !== jobsResponse.total_count) {
    throw new Error('publisher job response is incomplete; refusing to authorize release tags');
  }
  const exact = jobsResponse.jobs.filter(job => job.run_id === runId && job.run_attempt === runAttempt);
  const eligibility = exact.filter(job => job.name === 'eligibility');
  const publish = exact.filter(job => job.name === 'publish');
  if (eligibility.length !== 1 || eligibility[0].status !== 'completed' || eligibility[0].conclusion !== 'success') {
    throw new Error('publisher eligibility job did not complete successfully for the exact run attempt');
  }
  if (publish.length !== 1) throw new Error('publisher publish job is missing or duplicated for the exact run attempt');
  const expectedConclusion = isDryRun ? 'skipped' : 'success';
  if (publish[0].status !== 'completed' || publish[0].conclusion !== expectedConclusion) {
    throw new Error(`publisher publish job conclusion must be ${expectedConclusion} for this mode`);
  }
  return true;
}

export function publisherWatchArgs(runId) {
  return ['run', 'watch', String(runId), '--exit-status'];
}

export function publisherWatchTimeoutError(error, runId, timeoutMinutes = 45, cancelRequested = false) {
  const timedOut = error?.code === 'ETIMEDOUT' || (error?.killed === true && error?.signal === 'SIGTERM');
  if (timedOut) {
    const cancellation = cancelRequested ? 'cancel was requested' : 'cancellation failed';
    return new Error(`publisher run ${runId} exceeded the ${timeoutMinutes}-minute watch limit; no tags were created, but publication may have completed and ${cancellation}. Verify registry and run state before retrying.`);
  }
  return error;

}
