import { Shell } from "../../../components/Shell.jsx";
import { AdminSpace } from "../../../screens/Admin.jsx";

export const metadata = { title: "Comptes partenaires" };

export default function Page() {
  return <Shell><AdminSpace section="comptes" /></Shell>;
}
