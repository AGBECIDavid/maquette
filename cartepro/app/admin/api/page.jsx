import { Shell } from "../../../components/Shell.jsx";
import { AdminSpace } from "../../../screens/Admin.jsx";

export const metadata = { title: "API" };

export default function Page() {
  return <Shell><AdminSpace section="api" /></Shell>;
}
